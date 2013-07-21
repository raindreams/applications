/**
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include "util/cuPrintf.cu"

#include "hadoop/SerialUtils.hh"
#include "hadoop/StringUtils.hh"

#include <stdio.h>
#include <stdlib.h>

#include <signal.h>

#include <assert.h>
#include <errno.h>

#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>

#include <iostream>
#include <fstream>

#include <stdint.h>

#include <string.h>
#include <strings.h>

#include <pthread.h>

#include <cuda_runtime.h>

/********************************************/
/*************** MESSAGE_TYPE ***************/
/********************************************/
enum MESSAGE_TYPE {
	GET_NEXT_VALUE,
};

/********************************************/
/***************    Server    ***************/
/********************************************/
class SocketServer {
private:
	int sock;
	int port;
	bool done;

public:
	SocketServer() {
		sock = -1;
		port = -1;
		done = false;
	}

	~SocketServer() {
		fflush(stdout);
		if (sock != -1) {
			int result = shutdown(sock, SHUT_RDWR);
			if (result != 0) {
				fprintf(stderr, "SocketServer: problem shutting socket\n");
			}
			result = close(sock);
			if (result != 0) {
				fprintf(stderr, "SocketServer: problem closing socket\n");
			}
		}
	}

	int getPort() {
		return port;
	}

	void setDone(bool finished) {
		done = finished;
	}

	void *runSocketServer() {
		printf("SocketServer started!\n");

		sock = socket(PF_INET, SOCK_STREAM, 0);
		if (sock < 0) {
			fprintf(stderr, "SocketServer: problem creating socket: %s\n",
					strerror(errno));
		}

		sockaddr_in addr;
		memset((char *) &addr, 0, sizeof(addr));
		addr.sin_family = AF_INET;
		// bind to a OS-assigned random port.
		addr.sin_port = htons(0);
		addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

		int ret = bind(sock, (sockaddr*) &addr, sizeof(addr));
		if (ret < 0) {
			fprintf(stderr, "SocketServer: error on binding: %s\n",
					strerror(errno));
			return NULL;
		}

		// Get current port
		struct sockaddr_in current_addr;
		int current_addr_len = sizeof(current_addr);
		ret = getsockname(sock, (sockaddr*) &current_addr,
				(socklen_t *) &current_addr_len);
		if (ret < 0) {
			fprintf(stderr, "SocketServer: problem getsockname: %s\n",
					strerror(errno));
			return NULL;
		}
		port = ntohs(current_addr.sin_port);

		listen(sock, 5);

		printf("SocketServer is running @ port %d ...\n", port);

		do {
			printf("SocketServer is waiting for clients\n");

			sockaddr_in partnerAddr;
			int adrLen;
			int partnerSock = accept(sock, (sockaddr*) &partnerAddr,
					(socklen_t *) &adrLen);

			printf("SocketServer: Client connected.\n");

			FILE* in_stream = fdopen(sock, "r");
			FILE* out_stream = fdopen(sock, "w");
			HadoopUtils::FileInStream* inStream =
					new HadoopUtils::FileInStream();
			HadoopUtils::FileOutStream* outStream =
					new HadoopUtils::FileOutStream();
			inStream->open(in_stream);
			outStream->open(out_stream);

			//int32_t cmd;
			//cmd = HadoopUtils::deserializeInt(*inStream);

			//MsgLen = recv(IDPartnerSocket, Puffer, MAXPUF, 0);
			/* tu was mit den Daten */
			//send(IDPartnerSocket, Puffer, MsgLen, 0);
			close(partnerSock);

		} while (!done);

		printf("SocketServer stopped!\n");
		pthread_exit(0);
	}

	static void *SocketServer_thread(void *context) {
		return ((SocketServer *) context)->runSocketServer();
	}

};

/********************************************/
/**************     CLIENT     **************/
/********************************************/
class SocketClient {
private:
	int sock;
	FILE* in_stream;
	FILE* out_stream;
	HadoopUtils::FileInStream* inStream;
	HadoopUtils::FileOutStream* outStream;

public:
	SocketClient() {
		sock = -1;
		in_stream = NULL;
		out_stream = NULL;
	}

	void connectSocket(int port) {
		printf("SocketClient started\n");

		if (port <= 0) {
			printf("SocketClient: invalid port number!\n");
			return; /* Failed */
		}

		sock = socket(PF_INET, SOCK_STREAM, 0);
		if (sock == -1) {
			fprintf(stderr, "SocketClient: problem creating socket: %s\n",
					strerror(errno));
		}

		sockaddr_in addr;
		addr.sin_family = AF_INET;
		addr.sin_port = htons(port);
		addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

		int res = connect(sock, (sockaddr*) &addr, sizeof(addr));
		if (res != 0) {
			fprintf(stderr,
					"SocketClient: problem connecting command socket: %s\n",
					strerror(errno));
		}

		in_stream = fdopen(sock, "r");
		out_stream = fdopen(sock, "w");

		inStream = new HadoopUtils::FileInStream();
		inStream->open(in_stream);
		outStream = new HadoopUtils::FileOutStream();
		outStream->open(out_stream);

		printf("SocketClient is connected to port %d ...\n", port);
	}

	~SocketClient() {
		if (in_stream != NULL) {
			fflush(in_stream);
		}
		if (out_stream != NULL) {
			fflush(out_stream);
		}
		fflush(stdout);
		if (sock != -1) {
			int result = shutdown(sock, SHUT_RDWR);
			if (result != 0) {
				fprintf(stderr, "SocketClient: problem shutting down socket\n");
			}
			result = close(sock);
			if (result != 0) {
				fprintf(stderr, "SocketClient: problem closing socket\n");
			}
		}
	}

	__device__ __host__ int getNextValue() {

		HadoopUtils::serializeInt(GET_NEXT_VALUE,
				(HadoopUtils::OutStream &) *out_stream);
		//out_stream->flush();

		return 0;
	}
};

// global vars
SocketServer socket_server;
pthread_t t_socket_server;

void sigint_handler(int s) {
	printf("Main: caught signal %d\n", s);

	// wait for SocketServer
	socket_server.setDone(true);
	pthread_join(t_socket_server, NULL);

	exit(1);
}

/********************************************/
/***************     CUDA     ***************/
/********************************************/

// Convenience function for checking CUDA runtime API results
// can be wrapped around any runtime API call. No-op in release builds.
inline cudaError_t checkCuda(cudaError_t result) {
#if defined(DEBUG) || defined(_DEBUG)
	if (result != cudaSuccess) {
		fprintf(stderr, "CUDA Runtime Error: %s\n", cudaGetErrorString(result));
		assert(result == cudaSuccess);
	}
#endif
	return result;
}

__global__ void device_method(SocketClient *d_socket_client) {

	//d_socket_client

	//int val = d_object->getValue();
	//cuPrintf("Device object value: %d\n", val);
	//d_object->setValue(++val);
	//__threadfence();
}

int main(void) {

	// register SIGINT (STRG-C) handler
	struct sigaction sigIntHandler;
	sigIntHandler.sa_handler = sigint_handler;
	sigemptyset(&sigIntHandler.sa_mask);
	sigIntHandler.sa_flags = 0;
	sigaction(SIGINT, &sigIntHandler, NULL);

	// start socketServer
	pthread_create(&t_socket_server, NULL, &SocketServer::SocketServer_thread,
			&socket_server);

	SocketClient *host_client;
	SocketClient *device_client;

	// runtime must be placed into a state enabling to allocate zero-copy buffers.
	checkCuda(cudaSetDeviceFlags(cudaDeviceMapHost));

	// init pinned memory
	checkCuda(
			cudaHostAlloc((void**) &host_client, sizeof(SocketClient),
					cudaHostAllocWriteCombined | cudaHostAllocMapped));

	// connect SocketClient
	host_client->connectSocket(socket_server.getPort());

	int value = host_client->getNextValue();
	printf("Host client getNextValue: %d\n", value);

	checkCuda(cudaHostGetDevicePointer(&device_client, host_client, 0));

	// initialize cuPrintf
	cudaPrintfInit();

	//device_method<<<1, 1>>>(device_client);
	//device_method<<<16, 4>>>(device_client);

	// display the device's output
	cudaPrintfDisplay();
	// clean up after cuPrintf
	cudaPrintfEnd();

	//printf("Host object value: %d (after gpu execution) (thread_num=%d)\n",
	//		host_client->getValue(), 16 * 4);

	//assert(host_client->getValue() == 16*4);

	sleep(5);

	// wait for SocketServer
	socket_server.setDone(true);
	pthread_join(t_socket_server, NULL);

	return 0;
}
