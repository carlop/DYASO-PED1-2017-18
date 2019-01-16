#!/bin/bash
clear
printf "┍━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑\n"
printf "│                                           │\n"
printf "│  \e[1mMITOP por Francisco Carlos López Porcel\e[21m  │\n"
printf "│    PED1 - Sistemas Operativos - 2017/18   │\n"
printf "│                                           │\n"
printf "┝━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┙\n"

# Devuelve la lista de PID activos en el sistema
# 
# Lee todos los archivos y directorios de la carpeta /proc, con awk selecciona
# la novena columna, que es la que contiene el nombre del elemento, y con grep
# se selecciona solo aquellas que son un número, es decir, es el PID asociado a
# un proceso.
LISTAPID=$(ls -l /proc | awk '{print $9}' | grep "[0-9]")

# Número total de procesos
NUMEROPROCESOS=0

# Porcentaje total de uso del CPU
CPUTOTAL=0

# Sacamos PAGESIZE necesario para calcular el porcentaje de uso de memoria de
# cada proceso
PAGESIZE=$(getconf PAGESIZE)

# Extraemos la memoria total
MEMORIATOTAL=$(cat /proc/meminfo | awk '/MemTotal:/ {print $2}')

# Array con el tiempo total (usuario + núcleo) de cada proceso en la primera iteración
declare -A TIEMPOPROCESOS1

# Array con el uptime en cada proceso en la primera iteración
declare -A UPTIMEPROCESOS1

# Array con el tiempo total (usuario + núcleo) de cada proceso en la segunda iteración
declare -A TIEMPOPROCESOS2

# Array con el uptime en cada proceso en la segunda iteración
declare -A UPTIMEPROCESOS2

# Array con la información necesaria de cada proceso
declare -a PROCESOS

# Calculamos los ticks, necesarios para pasar los datos de tiempo de los procesos
# a segundos
TICKS=$(getconf CLK_TCK)

# Recorremos todos los procesos leyendo su tiempo de ejecución en modo usuario
# y modo núcleo y los guardamos para la posterior comparación
for p in $LISTAPID; do
  # Archivo stat correspondiente a cada proceso
  ARCHIVOSTAT="/proc/$p/stat"

  # Calculamos su tiempo solo si existe
  if [ -e "$ARCHIVOSTAT" ]; then
    # Extraemos la información del proceso
    STAT=$(cat $ARCHIVOSTAT)
    # Extraemos el tiempo de ejecución en modo usuario
    TIEMPOUSUARIO=$(awk '{print $14}' <<< "$STAT")
    # Extraemos el tiempo de ejecución en modo núcleo
    TIEMPONUCLEO=$(awk '{print $15}' <<< "$STAT")
    # Guardamos el tiempo total en el array correspondiente 
    TIEMPOPROCESOS1[$p]=$(($TIEMPOUSUARIO + $TIEMPONUCLEO))
    #Guardamos el uptime en el momento de capturar los datos de este proceso
    UPTIMEPROCESOS1[$p]=$(cat /proc/uptime | awk '{print $1}')
  fi

  # Aumentamos el número de procesos
  ((NUMEROPROCESOS++))
done

# Esperamos 1 segundo
sleep 1

# Volvemos a recorrer todos los procesos leyendo su tiempo de ejecución en modo
# usuario y modo núcleo y los guardamos para la posterior comparación
contador=0
for p in $LISTAPID; do
  # Archivo stat correspondiente a cada proceso
  ARCHIVOSTAT="/proc/$p/stat"

  # Calculamos su tiempo solo si existe
  if [ -e "$ARCHIVOSTAT" ]; then
    # Extraemos la información del proceso
    STAT=$(cat $ARCHIVOSTAT)

    # PID del proceso
    PID=$(awk '{print $1}' <<< "$STAT")

    # UID del usuario asociado al proceso
    USUARIOID=$(cat /proc/$p/status | awk '/Uid:/ {print $2}')
    # Nombre del usuario asociado al proceso
    USUARIO=$(awk -v var="$USUARIOID" 'BEGIN { FS=":" } {if (var == $3) print $1}' /etc/passwd)

    # Prioridad del proceso
    PR=$(awk '{print $18}' <<< "$STAT")

    # Tamaño de la memoria virtual del proceso
    VIRT=$(awk '{print $23}' <<< "$STAT")
    VIRT=$(($VIRT / 1024))

    # Estado del proceso
    S=$(awk '{print $3}' <<< "$STAT")

    # Extraemos el tiempo de ejecución en modo usuario
    TIEMPOUSUARIO2=$(awk '{print $14}' <<< "$STAT")
    # Extraemos el tiempo de ejecución en modo núcleo
    TIEMPONUCLEO2=$(awk '{print $15}' <<< "$STAT")
    # Guardamos el tiempo total en el array correspondiente 
    TIEMPOPROCESOS2[$p]=$(($TIEMPOUSUARIO2 + $TIEMPONUCLEO2 - ${TIEMPOPROCESOS1[$p]%.*}))

    #Guardamos el uptime en el momento de capturar los datos de este proceso
    UPTIMEPROCESOS2[$p]=$(cat /proc/uptime | awk '{print $1}')

    UPTIMETOTAL=$((${UPTIMEPROCESOS2[$p]%.*} - ${UPTIMEPROCESOS1[$p]%.*}))
    CPUPORCENTAJE=$(echo "scale=2; ${TIEMPOPROCESOS2[$p]%.*} / $UPTIMETOTAL" | bc | awk '{printf "%.2f", $0}')
    CPUTOTAL=$(echo $CPUTOTAL+$CPUPORCENTAJE | bc)

    # Valor rss del proceso
    RSS=$(awk '{print $24}' <<< "$STAT")

    # Porcentaje de memoria que está usando el proceso
    MEMORIAPORCENTAJE=$(echo "scale=2; ((($RSS * $PAGESIZE) / $MEMORIATOTAL) * 100) / 1024" | bc | awk '{printf "%.2f", $0}')

    # Tiempo de ejecución de un proceso
    TIEMPOPROCESO=$(awk '{print $22}' <<< "$STAT")
    # Pasamos el tiempo a segundos
    TIEMPOSEGUNDOS=$((${UPTIMEPROCESOS2[$p]%.*} - $TIEMPOPROCESO / $TICKS))
    # Formateamos la salida para que se muestre en hora:minuto:segundo
    TIEMPO=$(printf "%d:%02d:%02d" $(($TIEMPOSEGUNDOS/3600)) $(($TIEMPOSEGUNDOS%3600/60)) $(($TIEMPOSEGUNDOS%60)))

    # Nombre del programa invocado eliminando los paréntesis
    COMMAND=$(awk '{print $2}' <<< "$STAT" | sed -e 's/(//' -e 's/)//')

    # Se guardan todos los datos finales de cada proceso en el array PROCESOS
    PROCESOS[$contador]=$(printf "%-10s%-12s%-5s%-12s%-10s%-10s%-10s%-12s%-15s\n" $PID $USUARIO $PR $VIRT $S $CPUPORCENTAJE $MEMORIAPORCENTAJE $TIEMPO $COMMAND)

    ((contador++))
  fi
done

# Extraemos los datos del procesador
CPU=$(cat /proc/cpuinfo | awk '/model name/ {print $4 $5 $6 $7 $8 $9 $10}')

# Extraemos los datos del kernel
KERNEL=$(uname -r | awk '{print $1}')

# Extraemos los datos de la memoria restantes
MEMORIALIBRE=$(cat /proc/meminfo | awk '/MemFree:/ {print $2}')
MEMORIABUFFER=$(cat /proc/meminfo | awk '/Buffers:/ {print $2}')
MEMORIACACHEADA=$(cat /proc/meminfo | awk '/Cached:/ {print $2}' | head -1)
MEMORIASWAPCACHEADA=$(cat /proc/meminfo | awk '/SwapCached:/ {print $2}')
# Calculamos el tamaño de la memoria usada
MEMORIAUSADA=$(($MEMORIATOTAL - ($MEMORIALIBRE + $MEMORIABUFFER + $MEMORIACACHEADA + $MEMORIASWAPCACHEADA)))
# Pasamos los datos de memoria a Mb
MEMORIATOTAL=$(($MEMORIATOTAL / 1024))
MEMORIAUSADA=$(($MEMORIAUSADA / 1024))
MEMORIALIBRE=$(($MEMORIALIBRE / 1024))

# Mostramos la información de cabecera
printf "│\n"
printf "┝▸ Hostname:             \e[1m%s\e[21m\n" $HOSTNAME
printf "┝▸ Usuario:              \e[1m%s\e[21m\n" $USER
printf "┝▸ CPU:                  \e[1m%s\e[21m\n" $CPU
printf "┝▸ Kernel:               \e[1m%s\e[21m\n" $KERNEL
printf "┝▸ Nº de procesos:       \e[1m%d\e[21m\n" $NUMEROPROCESOS
printf "┝▸ Uso total de la CPU:  \e[1m%s %s\e[21m\n" $CPUTOTAL "%"
printf "┝▸ Memoria total:        \e[1m%s %s\e[21m\n" "$MEMORIATOTAL" "Mb"
printf "┝▸ Memoria utilizada:    \e[1m%s %s\e[21m\n" "$MEMORIAUSADA" "Mb"
printf "┝▸ Memoria libre:        \e[1m%s %s\e[21m\n" "$MEMORIALIBRE" "Mb"

# Muestra la lista de los 10 procesos con más uso de CPU
printf "│\n"
printf "┝━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑\n"
printf "│\e[1m  %-10s%-12s%-5s%-12s%-10s%-10s%-10s%-12s%-15s\e[21m │\n"  "PID" "USER" "PR" "VIRT" "S" "%CPU" "%MEM" "TIME" "COMMAND"
printf "┝━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┙\n"
# Ordenamos el array de procesos por %CPU, %MEM y TIME y lo limitamos a los 10
# primeros
IFS=$'\n' PROCESOSFINAL=($(sort -k6nr -k7nr -k8nr <<< "${PROCESOS[*]}" | head -10))
unset IFS
printf "│  %s\n" "${PROCESOSFINAL[@]}"
printf "┝━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┑\n"
printf "┕━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┙\n"
