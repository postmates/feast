//
// Copyright 2019 The Feast Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Code generated by protoc-gen-go. DO NOT EDIT.
// versions:
// 	protoc-gen-go v1.25.0
// 	protoc        v3.11.2
// source: feast/storage/Bigtable.proto

package storage

import (
	types "github.com/feast-dev/feast/sdk/go/protos/feast/types"
	proto "github.com/golang/protobuf/proto"
	protoreflect "google.golang.org/protobuf/reflect/protoreflect"
	protoimpl "google.golang.org/protobuf/runtime/protoimpl"
	reflect "reflect"
	sync "sync"
)

const (
	// Verify that this generated code is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(20 - protoimpl.MinVersion)
	// Verify that runtime/protoimpl is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(protoimpl.MaxVersion - 20)
)

// This is a compile-time assertion that a sufficiently up-to-date version
// of the legacy proto package is being used.
const _ = proto.ProtoPackageIsVersion4

type BigtableKey struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	// FeatureSet this row belongs to, this is defined as featureSetName.
	FeatureSet string `protobuf:"bytes,2,opt,name=feature_set,json=featureSet,proto3" json:"feature_set,omitempty"`
	// List of fields containing entity names and their respective values
	// contained within this feature row. The entities should be sorted
	// by the entity name alphabetically in ascending order.
	Entities []*types.Field `protobuf:"bytes,3,rep,name=entities,proto3" json:"entities,omitempty"`
}

func (x *BigtableKey) Reset() {
	*x = BigtableKey{}
	if protoimpl.UnsafeEnabled {
		mi := &file_feast_storage_Bigtable_proto_msgTypes[0]
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		ms.StoreMessageInfo(mi)
	}
}

func (x *BigtableKey) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*BigtableKey) ProtoMessage() {}

func (x *BigtableKey) ProtoReflect() protoreflect.Message {
	mi := &file_feast_storage_Bigtable_proto_msgTypes[0]
	if protoimpl.UnsafeEnabled && x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use BigtableKey.ProtoReflect.Descriptor instead.
func (*BigtableKey) Descriptor() ([]byte, []int) {
	return file_feast_storage_Bigtable_proto_rawDescGZIP(), []int{0}
}

func (x *BigtableKey) GetFeatureSet() string {
	if x != nil {
		return x.FeatureSet
	}
	return ""
}

func (x *BigtableKey) GetEntities() []*types.Field {
	if x != nil {
		return x.Entities
	}
	return nil
}

var File_feast_storage_Bigtable_proto protoreflect.FileDescriptor

var file_feast_storage_Bigtable_proto_rawDesc = []byte{
	0x0a, 0x1c, 0x66, 0x65, 0x61, 0x73, 0x74, 0x2f, 0x73, 0x74, 0x6f, 0x72, 0x61, 0x67, 0x65, 0x2f,
	0x42, 0x69, 0x67, 0x74, 0x61, 0x62, 0x6c, 0x65, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x12, 0x0d,
	0x66, 0x65, 0x61, 0x73, 0x74, 0x2e, 0x73, 0x74, 0x6f, 0x72, 0x61, 0x67, 0x65, 0x1a, 0x17, 0x66,
	0x65, 0x61, 0x73, 0x74, 0x2f, 0x74, 0x79, 0x70, 0x65, 0x73, 0x2f, 0x46, 0x69, 0x65, 0x6c, 0x64,
	0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x22, 0x5e, 0x0a, 0x0b, 0x42, 0x69, 0x67, 0x74, 0x61, 0x62,
	0x6c, 0x65, 0x4b, 0x65, 0x79, 0x12, 0x1f, 0x0a, 0x0b, 0x66, 0x65, 0x61, 0x74, 0x75, 0x72, 0x65,
	0x5f, 0x73, 0x65, 0x74, 0x18, 0x02, 0x20, 0x01, 0x28, 0x09, 0x52, 0x0a, 0x66, 0x65, 0x61, 0x74,
	0x75, 0x72, 0x65, 0x53, 0x65, 0x74, 0x12, 0x2e, 0x0a, 0x08, 0x65, 0x6e, 0x74, 0x69, 0x74, 0x69,
	0x65, 0x73, 0x18, 0x03, 0x20, 0x03, 0x28, 0x0b, 0x32, 0x12, 0x2e, 0x66, 0x65, 0x61, 0x73, 0x74,
	0x2e, 0x74, 0x79, 0x70, 0x65, 0x73, 0x2e, 0x46, 0x69, 0x65, 0x6c, 0x64, 0x52, 0x08, 0x65, 0x6e,
	0x74, 0x69, 0x74, 0x69, 0x65, 0x73, 0x42, 0x5c, 0x0a, 0x13, 0x66, 0x65, 0x61, 0x73, 0x74, 0x2e,
	0x70, 0x72, 0x6f, 0x74, 0x6f, 0x2e, 0x73, 0x74, 0x6f, 0x72, 0x61, 0x67, 0x65, 0x42, 0x0d, 0x42,
	0x69, 0x67, 0x74, 0x61, 0x62, 0x6c, 0x65, 0x50, 0x72, 0x6f, 0x74, 0x6f, 0x5a, 0x36, 0x67, 0x69,
	0x74, 0x68, 0x75, 0x62, 0x2e, 0x63, 0x6f, 0x6d, 0x2f, 0x66, 0x65, 0x61, 0x73, 0x74, 0x2d, 0x64,
	0x65, 0x76, 0x2f, 0x66, 0x65, 0x61, 0x73, 0x74, 0x2f, 0x73, 0x64, 0x6b, 0x2f, 0x67, 0x6f, 0x2f,
	0x70, 0x72, 0x6f, 0x74, 0x6f, 0x73, 0x2f, 0x66, 0x65, 0x61, 0x73, 0x74, 0x2f, 0x73, 0x74, 0x6f,
	0x72, 0x61, 0x67, 0x65, 0x62, 0x06, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x33,
}

var (
	file_feast_storage_Bigtable_proto_rawDescOnce sync.Once
	file_feast_storage_Bigtable_proto_rawDescData = file_feast_storage_Bigtable_proto_rawDesc
)

func file_feast_storage_Bigtable_proto_rawDescGZIP() []byte {
	file_feast_storage_Bigtable_proto_rawDescOnce.Do(func() {
		file_feast_storage_Bigtable_proto_rawDescData = protoimpl.X.CompressGZIP(file_feast_storage_Bigtable_proto_rawDescData)
	})
	return file_feast_storage_Bigtable_proto_rawDescData
}

var file_feast_storage_Bigtable_proto_msgTypes = make([]protoimpl.MessageInfo, 1)
var file_feast_storage_Bigtable_proto_goTypes = []interface{}{
	(*BigtableKey)(nil), // 0: feast.storage.BigtableKey
	(*types.Field)(nil), // 1: feast.types.Field
}
var file_feast_storage_Bigtable_proto_depIdxs = []int32{
	1, // 0: feast.storage.BigtableKey.entities:type_name -> feast.types.Field
	1, // [1:1] is the sub-list for method output_type
	1, // [1:1] is the sub-list for method input_type
	1, // [1:1] is the sub-list for extension type_name
	1, // [1:1] is the sub-list for extension extendee
	0, // [0:1] is the sub-list for field type_name
}

func init() { file_feast_storage_Bigtable_proto_init() }
func file_feast_storage_Bigtable_proto_init() {
	if File_feast_storage_Bigtable_proto != nil {
		return
	}
	if !protoimpl.UnsafeEnabled {
		file_feast_storage_Bigtable_proto_msgTypes[0].Exporter = func(v interface{}, i int) interface{} {
			switch v := v.(*BigtableKey); i {
			case 0:
				return &v.state
			case 1:
				return &v.sizeCache
			case 2:
				return &v.unknownFields
			default:
				return nil
			}
		}
	}
	type x struct{}
	out := protoimpl.TypeBuilder{
		File: protoimpl.DescBuilder{
			GoPackagePath: reflect.TypeOf(x{}).PkgPath(),
			RawDescriptor: file_feast_storage_Bigtable_proto_rawDesc,
			NumEnums:      0,
			NumMessages:   1,
			NumExtensions: 0,
			NumServices:   0,
		},
		GoTypes:           file_feast_storage_Bigtable_proto_goTypes,
		DependencyIndexes: file_feast_storage_Bigtable_proto_depIdxs,
		MessageInfos:      file_feast_storage_Bigtable_proto_msgTypes,
	}.Build()
	File_feast_storage_Bigtable_proto = out.File
	file_feast_storage_Bigtable_proto_rawDesc = nil
	file_feast_storage_Bigtable_proto_goTypes = nil
	file_feast_storage_Bigtable_proto_depIdxs = nil
}
