# This file was generated using the following command:
# ./configure --static --openblas-root=/kaldi/tools/OpenBLAS/install --mathlib=OPENBLAS --use-cuda=yes --cudatk-dir=/usr/local/cuda-8.0

# Rules that enable valgrind debugging ("make valgrind")

valgrind: .valgrind

.valgrind:
	echo -n > valgrind.out
	for x in $(TESTFILES); do echo $$x>>valgrind.out; valgrind ./$$x >/dev/null 2>> valgrind.out; done
	! ( grep 'ERROR SUMMARY' valgrind.out | grep -v '0 errors' )
	! ( grep 'definitely lost' valgrind.out | grep -v -w 0 )
	rm valgrind.out
	touch .valgrind


CONFIGURE_VERSION := 4
FSTROOT = /kaldi/tools/openfst
OPENFST_VER = 1.4.1
OPENFST_GE_10400 = 1
EXTRA_CXXFLAGS += -DHAVE_OPENFST_GE_10400 -std=gnu++0x
# makefiles/kaldi.mk.cygwin contains Cygwin-specific rules

OPENBLASROOT = /kaldi/tools/OpenBLAS/install
OPENBLASLIBS = $(OPENBLASROOT)/lib/libopenblas.a -lgfortran

ifndef FSTROOT
$(error FSTROOT not defined.)
endif

ifndef OPENBLASLIBS
$(error OPENBLASLIBS not defined.)
endif

ifndef OPENBLASROOT
$(error OPENBLASROOT not defined.)
endif

DOUBLE_PRECISION = 0

ifndef DOUBLE_PRECISION
$(error DOUBLE_PRECISION not defined.)
endif

CUDA = true
CUDATKDIR = /usr/local/cuda-8.0
CUDA_ARCH = -gencode arch=compute_20,code=sm_20 -gencode arch=compute_30,code=sm_30 -gencode arch=compute_35,code=sm_35 -gencode arch=compute_50,code=sm_50 -gencode arch=compute_53,code=sm_53

CUDA_INCLUDE= -I$(CUDATKDIR)/include
CUDA_FLAGS = -g -Xcompiler -fPIC --verbose --machine 64 -DHAVE_CUDA \
             -DKALDI_DOUBLEPRECISION=$(DOUBLE_PRECISION)
CXXFLAGS += -DHAVE_CUDA -I$(CUDATKDIR)/include
CUDA_LDFLAGS += -L$(CUDATKDIR)/lib/x64 -Wl,-rpath,$(CUDATKDIR)/lib/x64
CUDA_LDLIBS += -lcublas -lcudart -lcurand #LDLIBS : The libs are loaded later than static libs in implicit rule

CXXFLAGS = -msse -msse2 -Wall -I.. -DKALDI_DOUBLEPRECISION=$(DOUBLE_PRECISION) \
    -DHAVE_CLAPACK -I ../../tools/CLAPACK/ \
    -Wno-sign-compare -Wno-unused-local-typedefs -Winit-self \
    -I ../../tools/CLAPACK/ \
	-DHAVE_OPENBLAS -I $(OPENBLASROOT)/include \
    -I $(FSTROOT)/include \
    $(EXTRA_CXXFLAGS) \
    -g \
	-O -Wa,-mbig-obj # -O0 -DKALDI_PARANOID

ifeq ($(KALDI_FLAVOR), dynamic)
CXXFLAGS += -fPIC
endif

LDFLAGS = -g # --enable-auto-import
LDLIBS = $(EXTRA_LDLIBS) $(FSTROOT)/lib/libfst.a $(OPENBLASLIBS) -ldl -L/usr/lib/lapack \
         -lcyglapack-0 -lcygblas-0 -lm -lpthread # --enable-auto-import

CXX = g++
CC = g++
RANLIB = ranlib
AR = ar
AS = as
