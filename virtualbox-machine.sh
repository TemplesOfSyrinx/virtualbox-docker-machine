#!/bin/bash
# Creates a VirtualBox Server based on the name of the current directory.
#    ENV: NAME - Use environment variable to name the server instead of the directory name.
#         IP_ADDRESS - Use environment variable to assign an IP Address to the machine.
# If the default docker-compose.yaml file exists, it will be built.

MACHINE_NAME=${NAME:-`basename "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"`}

check_MACHINE_NAME() {
	if [ -z "$MACHINE_NAME" ]; then
	  echo 'machine name required'
	  exit 1
	fi
}

create() {
	check_MACHINE_NAME

# docker-machine create --driver virtualbox --help
#
#Options:
#   
#   --driver, -d "none"											Driver to create machine with. [$MACHINE_DRIVER]
	export MACHINE_DRIVER=${DRIVER:-virtualbox}
#   --engine-env [--engine-env option --engine-env option]						Specify environment variables to set in the engine
#   --engine-insecure-registry [--engine-insecure-registry option --engine-insecure-registry option]	Specify insecure registries to allow with the created engine
#   --engine-install-url "https://get.docker.com"							Custom URL to use for engine installation [$MACHINE_DOCKER_INSTALL_URL]
#   --engine-label [--engine-label option --engine-label option]						Specify labels for the created engine
#   --engine-opt [--engine-opt option --engine-opt option]						Specify arbitrary flags to include with the created engine in the form flag=value
#   --engine-registry-mirror [--engine-registry-mirror option --engine-registry-mirror option]		Specify registry mirrors to use [$ENGINE_REGISTRY_MIRROR]
#   --engine-storage-driver 										Specify a storage driver to use with the engine
#   --swarm												Configure Machine with Swarm
#   --swarm-addr 											addr to advertise for Swarm (default: detect and use the machine IP)
#   --swarm-discovery 											Discovery service to use with Swarm
#   --swarm-experimental											Enable Swarm experimental features
#   --swarm-host "tcp://0.0.0.0:3376"									ip/socket to listen on for Swarm master
#   --swarm-image "swarm:latest"										Specify Docker image to use for Swarm [$MACHINE_SWARM_IMAGE]
#   --swarm-master											Configure Machine to be a Swarm master
#   --swarm-opt [--swarm-opt option --swarm-opt option]							Define arbitrary flags for swarm
#   --swarm-strategy "spread"										Define a default scheduling strategy for Swarm
#   --tls-san [--tls-san option --tls-san option]							Support extra SANs for TLS certs
#   --virtualbox-boot2docker-url 									The URL of the boot2docker image. Defaults to the latest available version [$VIRTUALBOX_BOOT2DOCKER_URL]
#   --virtualbox-cpu-count "1"										number of CPUs for the machine (-1 to use the number of CPUs available) [$VIRTUALBOX_CPU_COUNT]
	export VIRTUALBOX_CPU_COUNT=${CPU_COUNT:-2}
#   --virtualbox-disk-size "20000"									Size of disk for host in MB [$VIRTUALBOX_DISK_SIZE]
	export VIRTUALBOX_DISK_SIZE=${DISK_SIZE:-20000}
#   --virtualbox-host-dns-resolver									Use the host DNS resolver [$VIRTUALBOX_HOST_DNS_RESOLVER]
#   --virtualbox-hostonly-cidr "192.168.99.1/24"								Specify the Host Only CIDR [$VIRTUALBOX_HOSTONLY_CIDR]
#   --virtualbox-hostonly-nicpromisc "deny"								Specify the Host Only Network Adapter Promiscuous Mode [$VIRTUALBOX_HOSTONLY_NIC_PROMISC]
#   --virtualbox-hostonly-nictype "82540EM"								Specify the Host Only Network Adapter Type [$VIRTUALBOX_HOSTONLY_NIC_TYPE]
#   --virtualbox-import-boot2docker-vm 									The name of a Boot2Docker VM to import [$VIRTUALBOX_BOOT2DOCKER_IMPORT_VM]
#   --virtualbox-memory "1024"										Size of memory for host in MB [$VIRTUALBOX_MEMORY_SIZE]
	export VIRTUALBOX_MEMORY_SIZE=${MEMORY_SIZE:-2048}
#   --virtualbox-nat-nictype "82540EM"									Specify the Network Adapter Type [$VIRTUALBOX_NAT_NICTYPE]
#   --virtualbox-no-dns-proxy										Disable proxying all DNS requests to the host [$VIRTUALBOX_NO_DNS_PROXY]
#   --virtualbox-no-share										Disable the mount of your home directory [$VIRTUALBOX_NO_SHARE]
#   --virtualbox-no-vtx-check										Disable checking for the availability of hardware virtualization before the vm is started [$VIRTUALBOX_NO_VTX_CHECK]

	docker-machine create \
		$MACHINE_NAME
}

connect() {
	eval $(docker-machine env $MACHINE_NAME)
}

start() {
	check_MACHINE_NAME

	docker-machine start $MACHINE_NAME
	# [--autostop-type disabled|savestate|poweroff|acpishutdown]
	echo "sudo VBoxManage modifyvm `VBoxManage list vms| grep $MACHINE_NAME | sed -r 's/.*\{(.*)\}/\1/'` --autostart-enabled on --autostop-type savestate"
}

stop() {
	check_MACHINE_NAME

	docker-machine stop $MACHINE_NAME
	echo "sudo VBoxManage modifyvm `VBoxManage list vms| grep $MACHINE_NAME | sed -r 's/.*\{(.*)\}/\1/'` --autostart-enabled off"
}

restart() {
	check_MACHINE_NAME

	stop && start
}

status() {
	check_MACHINE_NAME

	docker-machine status $MACHINE_NAME && docker-machine env $MACHINE_NAME
}

remove() {
	check_MACHINE_NAME

	docker-machine rm $MACHINE_NAME
}

setip() {
# Based on: https://github.com/fivestars/docker-machine-ipconfig/blob/master/docker-machine-ipconfig

        ip=${IP_ADDRESS:-$(docker-machine ip $MACHINE_NAME)}
	broadcast=${ip%.*}.255

cat <<EOF | docker-machine ssh $MACHINE_NAME "sudo tee /var/lib/boot2docker/bootsync.sh >/dev/null"
#!/bin/sh
# IP=$ip
# Stop the DHCP service for our host-only inteface
[[ -f /var/run/udhcpc.eth1.pid ]] && kill \$(cat /var/run/udhcpc.eth1.pid) 2>/dev/null || :
# Configure the interface to use the assigned IP address as a static address
ifconfig eth1 $ip netmask 255.255.255.0 broadcast $broadcast up
EOF

	stop && start && docker-machine regenerate-certs $MACHINE_NAME
}

build() {
	if [ -f docker-compose.yml ]; then
		connect && docker-compose build
	else
	  	echo 'docker compose YAML file not found: build not run'
	fi
}

case "$1" in
create)
    create
    ;;
connect)
    connect
    ;;
start)
    start
    ;;
stop)
    stop
    ;;
restart)
    restart
    ;;
status)
    status
    ;;
remove)
    remove
    ;;
build)
    build
    ;;
*)
    if [ ! -z "$1" ]; then
        echo "Usage: $0 {create|connect|start|stop|restart|status|remove|build} [ip address]"
        exit 1
    fi
    create && setip && build
esac

exit $RETVAL

