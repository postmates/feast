// Code generated by protoc-gen-go. DO NOT EDIT.
// source: feast/types/Field.proto

package types

import (
	fmt "fmt"
	proto "github.com/golang/protobuf/proto"
	math "math"
)

// Reference imports to suppress errors if they are not otherwise used.
var _ = proto.Marshal
var _ = fmt.Errorf
var _ = math.Inf

// This is a compile-time assertion to ensure that this generated file
// is compatible with the proto package it is being compiled against.
// A compilation error at this line likely means your copy of the
// proto package needs to be updated.
const _ = proto.ProtoPackageIsVersion3 // please upgrade the proto package

type Field struct {
	Name                 string   `protobuf:"bytes,1,opt,name=name,proto3" json:"name,omitempty"`
	Value                *Value   `protobuf:"bytes,2,opt,name=value,proto3" json:"value,omitempty"`
	XXX_NoUnkeyedLiteral struct{} `json:"-"`
	XXX_unrecognized     []byte   `json:"-"`
	XXX_sizecache        int32    `json:"-"`
}

func (m *Field) Reset()         { *m = Field{} }
func (m *Field) String() string { return proto.CompactTextString(m) }
func (*Field) ProtoMessage()    {}
func (*Field) Descriptor() ([]byte, []int) {
	return fileDescriptor_8c568a78dfaa9ca9, []int{0}
}

func (m *Field) XXX_Unmarshal(b []byte) error {
	return xxx_messageInfo_Field.Unmarshal(m, b)
}
func (m *Field) XXX_Marshal(b []byte, deterministic bool) ([]byte, error) {
	return xxx_messageInfo_Field.Marshal(b, m, deterministic)
}
func (m *Field) XXX_Merge(src proto.Message) {
	xxx_messageInfo_Field.Merge(m, src)
}
func (m *Field) XXX_Size() int {
	return xxx_messageInfo_Field.Size(m)
}
func (m *Field) XXX_DiscardUnknown() {
	xxx_messageInfo_Field.DiscardUnknown(m)
}

var xxx_messageInfo_Field proto.InternalMessageInfo

func (m *Field) GetName() string {
	if m != nil {
		return m.Name
	}
	return ""
}

func (m *Field) GetValue() *Value {
	if m != nil {
		return m.Value
	}
	return nil
}

func init() {
	proto.RegisterType((*Field)(nil), "feast.types.Field")
}

func init() {
	proto.RegisterFile("feast/types/Field.proto", fileDescriptor_8c568a78dfaa9ca9)
}

var fileDescriptor_8c568a78dfaa9ca9 = []byte{
	// 165 bytes of a gzipped FileDescriptorProto
	0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xff, 0xe2, 0x12, 0x4f, 0x4b, 0x4d, 0x2c,
	0x2e, 0xd1, 0x2f, 0xa9, 0x2c, 0x48, 0x2d, 0xd6, 0x77, 0xcb, 0x4c, 0xcd, 0x49, 0xd1, 0x2b, 0x28,
	0xca, 0x2f, 0xc9, 0x17, 0xe2, 0x06, 0x4b, 0xe8, 0x81, 0x25, 0xa4, 0x50, 0x54, 0x85, 0x25, 0xe6,
	0x94, 0xa6, 0x42, 0x54, 0x29, 0xb9, 0x72, 0xb1, 0x82, 0x35, 0x09, 0x09, 0x71, 0xb1, 0xe4, 0x25,
	0xe6, 0xa6, 0x4a, 0x30, 0x2a, 0x30, 0x6a, 0x70, 0x06, 0x81, 0xd9, 0x42, 0x1a, 0x5c, 0xac, 0x65,
	0x20, 0xb5, 0x12, 0x4c, 0x0a, 0x8c, 0x1a, 0xdc, 0x46, 0x42, 0x7a, 0x48, 0x46, 0xea, 0x81, 0x4d,
	0x09, 0x82, 0x28, 0x70, 0xf2, 0xe6, 0x42, 0xb6, 0xce, 0x89, 0x0b, 0x6c, 0x66, 0x00, 0xc8, 0x86,
	0x28, 0x83, 0xf4, 0xcc, 0x92, 0x8c, 0xd2, 0x24, 0xbd, 0xe4, 0xfc, 0x5c, 0xfd, 0xf4, 0xfc, 0xac,
	0xd4, 0x6c, 0x7d, 0x88, 0x5b, 0x8a, 0x53, 0xb2, 0xf5, 0xd3, 0xf3, 0xf5, 0xc1, 0xce, 0x28, 0xd6,
	0x47, 0x72, 0x5f, 0x12, 0x1b, 0x58, 0xcc, 0x18, 0x10, 0x00, 0x00, 0xff, 0xff, 0xef, 0xe8, 0xff,
	0x05, 0xdb, 0x00, 0x00, 0x00,
}
