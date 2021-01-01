
#       Makefile for Airborne Surveillance

#       Options for Gnuplot
GPOPTS =  -e "set terminal qt size 640,400 persist"

duh:
	@echo "What'll it be, mate?"

clean:
	rm -f *.gp *.gpd

plots:
	perl airborne_surveillance.pl airborne_surveillance_2020-12-27.csv

view:
	for region in *.gp ; do \
		gnuplot $(GPOPTS) $${region} ; \
	done

