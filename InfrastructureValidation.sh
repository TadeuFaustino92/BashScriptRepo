#!/bin/bash

#--------------------------------------------
# Declara��o de vari�veis globais auxiliares
#--------------------------------------------
USERNAME=$USER
HOSTNAME=$(hostname)



#---------------------------------------------------------------------------------
# Grava a entrada de dados do usu�rio em um arquivo, que ser� transmitido para os
# servidores armazenados no array gerado na fun��o gerarListaDeServidores().
#---------------------------------------------------------------------------------
echo "###################################################################################################################################################################"
echo "#                                                                                                                                                                 #"
echo "#                                                         ******************************************************                                                  #"
echo "#                                                         *                VALIDA��O DE TOPOLOGIA              *                                                  #"
echo "#                                                         *            LEIA TUDO ANTES DE COME�AR!!            *                                                  #"
echo "#                                                         ******************************************************                                                  #"
echo "#                                                                                                                                                                 #"
echo "#         1- Nome do sistema (apenas 5 caracteres), conforme exemplo: sisde, siaha, sinot, sifug...                                                               #"
echo "#                                                                                                                                                                 #"
echo "#         2- Nome do modulo: O grf por exemplo, e um modulo do sistema sisfg (ENTER caso n�o seja um modulo)                                                      #"
echo "#                                                                                                                                                                 #"
echo "#         3- Nome do site sem a sigla inicial (https-), sem o dominio (.hmp.corerj.caixa) e sem ambiente (.intra ou .inter) conforme exemplo abaixo.              #"
echo "#                 EX: https-sifge-web.inter.hmp.corerj.caixa (DIGITAR SOMENTE sifge-web                                                                           #"
echo "#                                                                                                                                                                 #"
echo "#         4- Ambiente para verificacao do site (digite inter para internet, intra para intranet), conforme exemplos:                                              #"
echo "#                 A) sifug.intra.hmp.corerj.caixa                                                                                                                 #"
echo "#                 B) sifug.inter.hmp.corerj.caixa                                                                                                                 #"
echo "#                                                                                                                                                                 #"
echo "#         4.1- Se o sistema a ser validado nao possuir as strings intra ou inter, conforme exemplo: siico.hmp.corerj.caixa (ENTER neste caso)                     #"
echo "#                                                                                                                                                                 #"
echo "#         5- Nome do arquivo de target sem a extensao (_jconnector.properties), (ENTER caso nao existam targets)                                                  #"
echo "#                                                                                                                                                                 #"
echo "#         6- Nome do arquivo de properties sem a extensao: .properties (ENTER caso nao existam properties), caso haja                                             #"
echo "#            mais de um propertie, separar por espa�o conforme exemplo:                                                                                           #"
echo "#                 EX: sifug_sisgr sifug_sifag sifug_xpto                                                                                                          #"
echo "#                                                                                                                                                                 #"
echo "###################################################################################################################################################################"


read -p "1- Entre com o nome do sistema: " sistema
echo $sistema | tr '[:upper:]' '[:lower:]' > ~/registro.txt

read -p "2- Entre com o nome do modulo (ENTER caso nao seja um modulo): " modulo
echo $modulo | tr '[:upper:]' '[:lower:]' >> ~/registro.txt

read -p "3- Entre com o nome do site sem a sigla inicial (https-), sem o dominio (.hmp.corerj.caixa) e sem o ambiente (.intra ou .inter): " site
echo $site | tr '[:upper:]' '[:lower:]' >> ~/registro.txt

read -p "4- Entre com o nome do ambiente (inter para internet, intra para intranet, ENTER caso nao existam estas strings no nome do site): " ambiente
echo $ambiente | tr '[:upper:]' '[:lower:]' >> ~/registro.txt

read -p "5- Entre com o nome do arquivo de target sem a extensao _jconnector.properties, (ENTER caso nao existam targets): " target
echo $target | tr '[:upper:]' '[:lower:]' >> ~/registro.txt

read -p "6- Entre com o nome do arquivo de properties sem a extensao: .properties (ENTER caso nao existam properties): " properties
echo $properties | tr '[:upper:]' '[:lower:]' | tr ' ' '\n' >> ~/registro.txt




#------------------------------------------------------------------------------------
# Fun��o que cria o Array de Servidores que ser� enviado para a fun��o "Conectar()"
#------------------------------------------------------------------------------------
gerarListaDeServidores() {
    i=0
    while true
    do
        read -p "Entre com o nome do servidor para a validacao de topologia (@ para terminar): " nomeServidor
        if [[ "$nomeServidor" == "@" ]]
        then
            break
        elif ping -c1 $nomeServidor &>/dev/null     # && $nomeServidor == $HOSTNAME
        then 
            ARRAY[$i]=$nomeServidor
            echo "O servidor "$nomeServidor" existe"
        else
            echo "O servidor "$nomeServidor" nao existe ou econtra-se indisponivel"
        fi  
        (( i++ ))
    done
   
    ARRAY_UNICO=($(echo "${ARRAY[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))           # O Shell enxerga um array como elementos numa �nica linha separados por espa�o
   
    Conectar ARRAY_UNICO[@]
}


#-----------------------------------------------------------------------------------------
# Fun��o respons�vel por receber os par�metros de entrada para a valida��o, transmiti-los
# atrav�s de um arquivo para os servidores listados na fun��o "gerarDadosDeEntrada()",
# conectar via SSH nestes servidores, chamar o script de valida��o remoto e por fim,
# copiar para o servidor local os relat�rios de cada membro do array de servidores
# da fun��o anterior.
#-----------------------------------------------------------------------------------------
Conectar() {
    declare -a SERVIDOR=("${!1}")
    echo "${SERVIDOR[@]}"   # Remover mais tarde
   
    echo -e "\n\"Digite sua senha UNIX/LINUX:\"\n"
    read -s password

for i in "${SERVIDOR[@]}"; do
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
# Chamada da Fun��o gerarListaDeServidores() e remo��o do arquivo tempor�rio
#-----------------------------------------------------------------------------------------
gerarListaDeServidores

rm -f ~/registro.txt
