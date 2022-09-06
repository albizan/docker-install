#!/bin/bash

# Download docker binaries from https://download.docker.com/linux/static/stable/x86_64/
# Download docker competion file from https://raw.githubusercontent.com/docker/cli/master/contrib/completion/bash/docker

check_file(){
    local file=$1
    if [[ ! -e $file ]];then
        color_echo $red "$file file not exist!\n"
        exit 1
    elif [[ ! -f $file ]];then
        color_echo $red "$file not a file!\n"
        exit 1
    fi

    file_name=$(echo ${file##*/})
    file_path=$(full_path $file)
    if [[ !  $file_name =~ ".tgz" && !  $file_name =~ ".tar.gz" ]];then
        color_echo $red "$file not a tgz file!\n"
        echo -e "please download docker binary file: $(color_echo $fuchsia $download_url)\n"
        exit 1
    fi
}

write_service(){
        mkdir -p /usr/lib/systemd/system/
        cat > /usr/lib/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
 
[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process
# restart the docker process if it exits prematurely
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
 
[Install]
WantedBy=multi-user.target
EOF
}


offline_install(){
    local origin_path=$(pwd)
    cd $file_path
    tar xzvf $file_name
    cp -rf docker/* /usr/bin/
    rm -rf docker
    cd ${origin_path} >/dev/null
    if [[ -e docker.bash || -e $file_path/docker.bash ]];then
        [[ -e docker.bash ]] && completion_file_path=`full_path docker.bash` || completion_file_path=$file_path
        cp -f $completion_file_path/docker.bash /usr/share/bash-completion/completions/docker
        chmod +x /usr/share/bash-completion/completions/docker
        source /usr/share/bash-completion/completions/docker
    fi
}

set_sysctl(){
    for conf in ${sysctl_list[@]}
    do
        check=`sysctl $conf 2>/dev/null`
        if [[ `echo $check` =~ "0" || -z `echo $check` ]];then
            if [[ `cat /etc/sysctl.conf` =~ "$conf" ]];then
                sed -i "s/^$conf.*/$conf=1/g" /etc/sysctl.conf
            else
                echo "$conf=1" >> /etc/sysctl.conf
            fi
            sysctl -p >/dev/null 2>&1
        fi
    done
}

main(){
    check_sys
    if [[ $standard_mode == 1 ]];then
        standard_install
    else
        [[ $offline_file ]] && offline_install || online_install
        write_service
        systemctl daemon-reload
    fi
    set_sysctl
    systemctl enable docker.service
    systemctl restart docker
    echo -e "docker $(color_echo $blue $(docker info|grep 'Server Version'|awk '{print $3}')) install success!"
}

main