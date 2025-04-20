FLAG = -fPIC

PYTHON_INC = -I/usr/include/python3.13/
PYTHIN_LINK = -Xlinker -export-dynamic

all:
	swig -c++ -python -o BusAccessCxx.cxx BusAccessCxx.i
	g++ $(FLAG) $(PYTHON_INC) -c BusAccessCxx.cxx -o BusAccessCxx.o
	g++ $(PYTHIN_LINK) -shared ../bin/Release/libBusAccess.so BusAccessCxx.o -o _BusAccess.so

