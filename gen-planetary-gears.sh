# ./run-example.sh 38 -o ~/Downloads/planetary-gearbox-m3.step -stl
# 3 planets:
./run-example.sh 38 --module 0.5 --gearLength  5 --outerThickness 1.66667 --tolerance 0.042 --holeRadius 1.66667 -stl -o ~/Downloads/planetary-gearbox-m0.5-tol.042.step 
./run-example.sh 38 --module 1.0 --gearLength 10 --outerThickness 3.33333 --tolerance 0.042 --holeRadius 3.33333 -stl -o ~/Downloads/planetary-gearbox-m1-tol.042.step 
./run-example.sh 38 --module 1.5 --gearLength 15 --outerThickness 5       --tolerance 0.042 --holeRadius 5       -stl -o ~/Downloads/planetary-gearbox-m1.5-tol.042.step 
./run-example.sh 38 --module 2.0 --gearLength 20 --outerThickness 6.66666 --tolerance 0.042 --holeRadius 6.66666 -stl -o ~/Downloads/planetary-gearbox-m2-tol.042.step
# 4 planets:
./run-example.sh 38 --module 0.5 --gearLength  5 --outerThickness 1.66667 --tolerance 0.042 --holeRadius 1.66667 -p 4 -stl -o ~/Downloads/planetary-gearbox-m0.5-p4-tol.042.step 
./run-example.sh 38 --module 1.0 --gearLength 10 --outerThickness 3.33333 --tolerance 0.042 --holeRadius 3.33333 -p 4 -stl -o ~/Downloads/planetary-gearbox-m1-p4-tol.042.step 
./run-example.sh 38 --module 1.5 --gearLength 15 --outerThickness 5       --tolerance 0.042 --holeRadius 5       -p 4 -stl -o ~/Downloads/planetary-gearbox-m1.5-p4-tol.042.step 
./run-example.sh 38 --module 2.0 --gearLength 20 --outerThickness 6.66666 --tolerance 0.042 --holeRadius 6.66666 -p 4 -stl -o ~/Downloads/planetary-gearbox-m2-p4-tol.042.step
