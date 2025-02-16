#!/bin/bash
if [[ -z $1 ]] || [[ -z $2 ]]
then
    echo
    echo "La sintaxis es: $0 archivo_csv carpeta_destino"
    echo
else
	# Creamos la carpeta destino si no existe
	if [ ! -d $2 ]; then
		mkdir $2
	fi
	wildcard_file="$2/wildcard.txt"
	domains_file="$2/domains.txt"
	domains_uniq_file="$2/domains_uniq.txt"
	# Wildcards
	if [ ! -f $wildcard_file ]
	then
			touch $wildcard_file
		else
			rm $wildcard_file
			touch $wildcard_file
	fi
	# Dominios
	if [ ! -f $domains_file ]
	then
			touch $domains_file
		else
			rm $domains_file
			touch $domains_file
	fi
	while IFS="," read -r dominio tipo rec_column3 bounty scope rec_remaining
	do
		if [ $scope == true ]
		then
			if [ $tipo == 'WILDCARD' ]
			then
				echo $dominio >> $wildcard_file
			else
				echo $dominio >> $domains_file
			fi
	   	fi
	done < <(tail -n +2 $1)
	cat $wildcard_file | sed 's/^..//' >> $domains_file		# Ponemos los wildcards sin * en dominios
	
	sort -u $domains_file > $domains_uniq_file		# Quitamos repetidos en dominios
fi