#python2.4 /usr/local/pkgs/mpich2-eth-pgi-4.1/bin/mpiexec.py -l -envall -n 2 /home/steder/software/bin/python2.4 /home/steder/pyCPL/coupler.py

MPIEXEC=/usr/local/pkgs/mpich2-eth-pgi-4.1/bin/mpiexec.py 

/home/steder/software/bin/python2.4 $MPIEXEC -l -envall -n 1 /home/steder/pyCPL/xcpl : -n 1 /home/steder/pyCPL/xatm