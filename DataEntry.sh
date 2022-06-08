#!/bin/bash

#--------------------------------------------
# Global varibles
#--------------------------------------------
USERNAME=$USER
HOSTNAME=$(hostname)


#---------------------------------------------------------------------------------
# User Input
#---------------------------------------------------------------------------------
echo "###################################################################################################################################################################"
echo "#                                                                                                                                                                 #"
echo "#                                                         ******************************************************                                                  #"
echo "#                                                         *                VALIDAÇÃO DE TOPOLOGIA              *                                                  #"
echo "#                                                         *            LEIA TUDO ANTES DE COMEÇAR!!            *                                                  #"
echo "#                                                         ******************************************************                                                  #"
echo "#                                                                                                                                                                 #"
echo "#         1- System name (5 characters only), exemple: xxxxx, yyyyy, zzzzz...                                                                                     #"
echo "#                                                                                                                                                                 #"
echo "#         2- Module name: xxx for example, a module of xxxxx system (type ENTER if it's not a module)                                                             #"
echo "#                                                                                                                                                                 #"
echo "#         3- website name, ignore https-, dommain .env.unit.company and environment .intra/.inter as example below.                                               #"
echo "#                 EX: https-xxxxx-web.inter.env.roce.aicax (TYPE sifge-web)                                                                                       #"
echo "#                                                                                                                                                                 #"
echo "#         4- Environment (type inter for internet, intra for intranet), as examples:                                                                              #"
echo "#                 A) xxxxx.inter.env.roce.aicax                                                                                                                   #"
echo "#                 B) yyyyy.inter.env.roce.aicax                                                                                                                   #"
echo "#                                                                                                                                                                 #"
echo "#         4.1- In case there no environment intra or inter: xxxxx.env.roce.aicax (type ENTER in this case)                                                        #"
echo "#                                                                                                                                                                 #"
echo "#         5- Target file name without it's extension (_jconnector.properties), (type ENTER if there are no target files), use space for adding additional files   #"
echo "#                                                                                                                                                                 #"
echo "#         6- Properties file name without it's extension: .properties (type ENTER if there are no properties files), use space for adding additional files        #"
echo "#                                                                                                                                                                 #"
echo "###################################################################################################################################################################"


read -p "1- Type system name: " system
echo $system | tr '[:upper:]' '[:lower:]' > ~/registro.txt

read -p "2- Type module name: " module
echo $modulo | tr '[:upper:]' '[:lower:]' >> ~/registro.txt

read -p "3- Type website name: " site
echo $site | tr '[:upper:]' '[:lower:]' >> ~/registro.txt

read -p "4- Type environment name: " environment
echo $environment | tr '[:upper:]' '[:lower:]' >> ~/registro.txt

read -p "5- Type target file name: " target
echo $target | tr '[:upper:]' '[:lower:]' >> ~/registro.txt

read -p "6- Type properties file name: " properties
echo $properties | tr '[:upper:]' '[:lower:]' | tr ' ' '\n' >> ~/registro.txt


#------------------------------------------------------------------------------------
# Function for creating an array to be used on "Connect()"
#------------------------------------------------------------------------------------
createServerList() {
    i=0
    while true
    do
        read -p "Please input server name (type @ to finish): " serverName
        if [[ "$serverName" == "@" ]]
        then
            break
        elif ping -c1 $serverName &>/dev/null     # && $serverName == $HOSTNAME
        then 
            ARRAY[$i]=$serverName
            echo "Server "$serverName" is alive"
        else
            echo "Server "$serverName" is down"
        fi  
        (( i++ ))
    done
   
    ARRAY_UNICO=($(echo "${ARRAY[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
   
    Connect ARRAY_UNICO[@]
}

Connect() {
    declare -a SERVER=("${!1}")
    echo "${SERVER[@]}"
   
    echo -e "\n\"Please type your UNIX/LINUX password:\"\n"
    read -s password

for i in "${SERVER[@]}"; do
/usr/bin/expect << EOF
    spawn scp registro.txt validacao3.sh $USERNAME@$i:~
    expect {
        "continue connecting" {
            send "yes\r"
                expect {
                    "?assword:" {
                            send "${password}\r"
                            expect eof
                    }
                }
        }
        "?assword:" {
            send "${password}\r"
            expect eof
        }
    }
EOF
done


for i in "${SERVIDOR[@]}"; do
/usr/bin/expect << EOF  
    spawn ssh -q $USERNAME@$i bash ./validacao3.sh
    expect {
        "continue connecting" {
            send "yes\r"
            expect {
                "?assword:" {
                    send "${password}\r"
                    expect eof
                }
            }
        }
        "?assword:" {
            send "${password}\r"
            expect eof
        }
    }
   
    spawn scp $USERNAME@$i:/export/home/$USERNAME/*.txt /export/home/$USERNAME/
    expect {
        "continue connecting" {
            send "yes\r"
            expect {
                "?assword:" {
                    send "${password}\r"
                    expect eof
                }
            }
        }
        "?assword:" {
            send "${password}\r"
            expect eof
        }
    }
EOF
done
}


#-----------------------------------------------------------------------------------------
# Callig gerarListaDeServidores() function and removing temporary file
#-----------------------------------------------------------------------------------------
createServerList

rm -f ~/registro.txt
