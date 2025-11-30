# =================================================================
# 1. 프로젝트 경로 및 변수 설정
# =================================================================
VENDOR_PATH := third_party
SRC_DIR := src
BUILD_DIR := build

# 최종 실행 파일 이름
TARGET := $(BUILD_DIR)/embedded_profiler

# BPF 및 스켈레톤 관련 파일 경로
BPF_OBJ := $(BUILD_DIR)/profiler.bpf.o
SKEL_HDR := $(BUILD_DIR)/profiler.skel.h

# 소스 파일 자동 탐색 (wildcard 사용)
USER_SRC := $(wildcard $(SRC_DIR)/app/*.cpp) $(wildcard $(SRC_DIR)/app/*.c)
BPF_SRC := $(SRC_DIR)/bpf/profiler.bpf.c

# =================================================================
# 2. 아키텍처 자동 감지 및 헤더 경로 설정 (중요!)
# =================================================================
# 시스템 아키텍처 감지 (aarch64 -> arm64)
# Clang 타겟용 아키텍처 이름
ARCH ?= $(shell uname -m | sed 's/x86_64/x86/' | sed 's/aarch64/arm64/' | sed 's/ppc64le/powerpc/' | sed 's/mips.*/mips/')

# [수정됨] 시스템 헤더 경로 자동 감지
# 라즈베리 파이(Debian 계열)는 헤더가 /usr/include/<arch>-linux-gnu 에 있음
# 예: /usr/include/aarch64-linux-gnu
HOST_ARCH := $(shell uname -m)
SYS_INCLUDES := -I/usr/include/$(HOST_ARCH)-linux-gnu -I/usr/include

# =================================================================
# 3. 툴체인 설정
# =================================================================
CLANG ?= clang
CXX ?= g++
BPFTOOL ?= bpftool

# =================================================================
# 4. 라이브러리 링크 전략 (하이브리드)
# =================================================================
# 1. 정적 링크 (내 프로젝트 내 라이브러리 사용 -> 이식성 확보)
STATIC_LIBS := $(VENDOR_PATH)/lib/libbpf.a \
               $(VENDOR_PATH)/lib/libelf.a \
               $(VENDOR_PATH)/lib/libz.a

# 2. 동적 링크 (시스템 라이브러리 사용 -> 충돌 방지)
SYS_LIBS := -lpthread -lrt -ldl

# 최종 링크 변수
LIBS := $(STATIC_LIBS) $(SYS_LIBS)

# =================================================================
# 5. 컴파일 플래그
# =================================================================

# [사용자 공간 C++] 컴파일 플래그
USER_CFLAGS := -g -O2 -Wall -std=c++17 \
               -I$(VENDOR_PATH)/include \
               -I$(SRC_DIR)/include \
               -I$(BUILD_DIR)

# [BPF 커널 C] 컴파일 플래그
# [수정됨] $(SYS_INCLUDES) 추가 -> asm/types.h 에러 해결
BPF_CFLAGS := -g -O2 -target bpf -D__TARGET_ARCH_$(ARCH) \
              -I$(VENDOR_PATH)/include \
              -I$(SRC_DIR)/include \
              -I$(BUILD_DIR) \
              $(SYS_INCLUDES)

# =================================================================
# 6. 빌드 규칙 (Recipes)
# =================================================================
.PHONY: all clean

all: $(BUILD_DIR) $(TARGET)

# (0) 빌드 디렉토리 생성
$(BUILD_DIR):
	mkdir -p $@

# (1) BPF 소스 -> 오브젝트 파일(.o) 컴파일
$(BPF_OBJ): $(BPF_SRC)
	$(CLANG) $(BPF_CFLAGS) -c $< -o $@
	@echo "--- ⚙️  Compiled BPF object: $@ (Arch: $(ARCH)) ---"

# (2) BPF 오브젝트 -> 스켈레톤 헤더(.skel.h) 생성
$(SKEL_HDR): $(BPF_OBJ)
	$(BPFTOOL) gen skeleton $< > $@
	@echo "--- 📝 Generated BPF skeleton: $@ ---"

# (3) C++ 애플리케이션 컴파일 및 최종 링크
$(TARGET): $(USER_SRC) $(SKEL_HDR)
	$(CXX) $(USER_CFLAGS) -o $@ $(USER_SRC) $(LIBS)
	@echo "--- 🟢 Successfully built target: $@ ---"

# =================================================================
# 7. 정리 (Clean)
# =================================================================
clean:
	rm -rf $(BUILD_DIR)
	@echo "--- 🧹 Cleaned up build artifacts ---"