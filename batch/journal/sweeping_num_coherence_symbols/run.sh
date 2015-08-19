#!/bin/bash

seeds=(26717 93365 50261 21138 66869 27791 12175 69683 410 57971)

for seed in ${seeds[*]}
do
    echo "Performing with seed $seed..."
    ./perform_one.jl --seed $seed
done

echo "Merging..."
./merge.jl num_coherence_symbols-seed*.jld

echo "Plotting..."
./plot.jl
