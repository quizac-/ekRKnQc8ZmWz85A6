all: percentage_filter

percentage_filter: percentage_filter.o
	gcc percentage_filter.o -o percentage_filter -lnetfilter_queue

percentage_filter.o: percentage_filter.c
	gcc -Wall -c percentage_filter.c

clean:
	rm -f percentage_filter.o percentage_filter

