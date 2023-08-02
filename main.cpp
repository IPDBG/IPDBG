#include <iostream>
#include "proxy.h"

int main(int argc, char* argv[]){
   try{
        if(argc != 2){
            //argv[1]: filename is required
            std::cerr<<"Usage error: filename is required" << std::endl;
            return 1;
        }

    }
    catch (std::exception& e){
        std::cerr<< e.what() << std::endl;
    }

    proxy proxy(argv[1]);

    while(1){
        proxy.toggle();
    }
    return 0;
}
