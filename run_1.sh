
for s in  80 81 82 83 84 85 86 87 88 89; do
	(
		./lamodel -P 1 -T $i -S 19$s 
		./lamodel -P 1 -T $i -S 19$s  -L 
	) &
done

