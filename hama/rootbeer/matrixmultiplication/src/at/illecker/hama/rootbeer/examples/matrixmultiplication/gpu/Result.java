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
package at.illecker.hama.rootbeer.examples.matrixmultiplication.gpu;

public class Result {

  public int thread_idxx;
  public int block_idxx;
  public int threadSliceSize;
  public int blockSliceSize;

  public int[][] bColsSharedMemIndex = null;
  public double[][] bColsSharedMemValues = null;

  public double[][] multipliers = null;
  public int[][][] bColsIndexes = null;
  public double[][][] bColsVals = null;

  public int[][] threadResultsSharedMemIndex = null;
  public double[][] threadResultsSharedMemValues = null;

  public int[][][] blockResultsSharedMemIndex = null;
  public double[][][] blockResultsSharedMemValues = null;

  // output
  public int[] resultColsIndex = null;
  public double[][] resultCols = null;

  @Override
  public String toString() {
    StringBuilder ret = new StringBuilder();
    ret.append("calc row: \n");
    ret.append("  thread_idxx: ");
    ret.append(thread_idxx);
    ret.append("\n");

    ret.append("  block_idxx: ");
    ret.append(block_idxx);
    ret.append("\n");

    ret.append("  threadSliceSize: ");
    ret.append(threadSliceSize);
    ret.append("\n");

    ret.append("  blockSliceSize: ");
    ret.append(blockSliceSize);

    return ret.toString();
  }
}
