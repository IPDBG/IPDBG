all:
	swig -c++ -octave -o BusAccessCxx.cxx BusAccessCxx.i
	mkoctfile BusAccessCxx.cxx -L../bin/Release -lBusAccess -o BusAccess.oct
