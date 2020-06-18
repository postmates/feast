/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright 2018-2020 The Feast Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package feast.storage.connectors.bigtable.retriever;

import com.google.api.gax.rpc.ResponseObserver;
import com.google.api.gax.rpc.StreamController;
import com.google.cloud.bigtable.data.v2.models.Row;
import com.google.cloud.bigtable.data.v2.models.RowCell;
import com.google.protobuf.ByteString;
import com.google.protobuf.Descriptors.Descriptor;
import feast.proto.core.FeatureSetProto.FeatureSetSpec;
import feast.proto.core.FeatureSetProto.FeatureSpec;
import feast.proto.serving.ServingAPIProto.FeatureReference;
import feast.proto.storage.BigtableProto.BigtableKey;
import feast.proto.types.FeatureRowProto.FeatureRow;
import feast.proto.types.FeatureRowProto.FeatureRow.Builder;
import feast.proto.types.FieldProto.Field;
import feast.proto.types.ValueProto.Value;
import io.grpc.Status;
import java.util.HashMap;
import java.util.List;

public class BigtableOnlineObserver implements ResponseObserver<Row> {

  private final List<BigtableKey> bigtableKeys;
  private final FeatureSetSpec featureSetSpec;
  private final List<FeatureReference> featureReferences;
  private static final String METADATA_CF = "metadata";
  private static final String FEATURES_CF = "features";
  private static final ByteString FEATURE_SET_QUALIFIER = ByteString.copyFromUtf8("feature_set");
  private static final ByteString INGESTION_ID_QUALIFIER = ByteString.copyFromUtf8("ingestion_id");
  private static final ByteString EVENT_TIMESTAMP_QUALIFIER =
      ByteString.copyFromUtf8("event_timestamp");
  private HashMap<ByteString, Builder> resultMap;
  private HashMap<ByteString, Descriptor> featureMap;
  private List<FeatureRow> result;

  private BigtableOnlineObserver(
      List<BigtableKey> bigtableKeys,
      FeatureSetSpec featureSetSpec,
      List<FeatureReference> featureReferences,
      List<FeatureRow> result) {
    this.bigtableKeys = bigtableKeys;
    this.featureSetSpec = featureSetSpec;
    this.featureReferences = featureReferences;
    this.resultMap = new HashMap<>();
    this.featureMap = new HashMap<>();
    this.result = result;
  }

  public static ResponseObserver create(
      List<BigtableKey> bigtableKeys,
      FeatureSetSpec featureSetSpec,
      List<FeatureReference> featureReferences,
      List<FeatureRow> result) {
    return new BigtableOnlineObserver(bigtableKeys, featureSetSpec, featureReferences, result);
  }

  public List<FeatureRow> getResult() {
    return this.result;
  }

  @Override
  public void onStart(StreamController streamController) {
    List<FeatureSpec> featuresList = this.featureSetSpec.getFeaturesList();
    HashMap<String, Descriptor> allFeatureMap = new HashMap<>();
    for (FeatureSpec spec : featuresList) {
      allFeatureMap.put(spec.getName(), spec.getDescriptorForType());
    }
    Builder nullFeatureRowBuilder =
        FeatureRow.newBuilder().setFeatureSet(generateFeatureSetStringRef(featureSetSpec));

    for (FeatureReference featureReference : featureReferences) {
      nullFeatureRowBuilder.addFields(Field.newBuilder().setName(featureReference.getName()));
      this.featureMap.put(
          ByteString.copyFromUtf8(featureReference.getName()),
          allFeatureMap.get(featureReference.getName()));
    }
    for (BigtableKey bigtableKey : bigtableKeys) {
      this.resultMap.put(bigtableKey.toByteString(), nullFeatureRowBuilder);
    }
  }

  @Override
  public void onResponse(Row row) {
    List<RowCell> metadata = row.getCells(METADATA_CF);
    Builder resultBuilder = resultMap.get(row.getKey());
    for (RowCell rowValues : row.getCells(FEATURES_CF)) {
      try {
        if (featureMap.containsKey(rowValues.getQualifier())) {
          resultBuilder.addFields(
              Field.newBuilder()
                  .setNameBytes(rowValues.getQualifier())
                  .setValue(
                      Value.newBuilder()
                          .setField(
                              featureMap
                                  .get(rowValues.getQualifier())
                                  .findFieldByName(rowValues.getQualifier().toStringUtf8()),
                              rowValues.getValue())
                          .build())
                  .build());
        }
      } catch (Exception e) {
        throw Status.NOT_FOUND
            .withCause(e)
            .withDescription("There was a problem getting the right cells")
            .asRuntimeException();
      }
    }
  }

  @Override
  public void onError(Throwable throwable) {
    throw Status.INTERNAL
        .withDescription("Encountered an error in a bigtable query")
        .withCause(throwable)
        .asRuntimeException();
  }

  @Override
  public void onComplete() {
    for (BigtableKey key : bigtableKeys) {
      if (!resultMap.containsKey(key)) {
        throw Status.INVALID_ARGUMENT
            .withDescription("Somehow a bigtable key did not receive a builder in the resultMap")
            .asRuntimeException();
      } else {
        FeatureRow finalRow = resultMap.get(key).build();
        result.add(finalRow);
      }
    }
  }

  private static String generateFeatureSetStringRef(FeatureSetSpec featureSetSpec) {
    String ref = String.format("%s/%s", featureSetSpec.getProject(), featureSetSpec.getName());
    return ref;
  }
}
