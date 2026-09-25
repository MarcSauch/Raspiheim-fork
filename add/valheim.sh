#!/bin/bash
export PATH=/usr/local/bin/:$PATH

mkdir -p /data/logs /data/worlds_local

#Manage Box86/64 version
if [ "$BOX86" != "default" ];
then	installed="$(apt-cache policy box86-rpi4arm64 | grep Installed | awk '{print $2}')"
		wanted="$(apt-cache policy box86-rpi4arm64 | grep 500 | grep "$BOX86" | awk 'NR==1 {print $2}')"
		latest="$(apt-cache policy box86-rpi4arm64 | grep Candidate | awk '{print $2}')"

	if [ "$BOX86" = "latest" ] && [ "$installed" != "$latest" ];
			then apt-get purge box86-rpi4arm64 -y && apt-get install box86-rpi4arm64=$latest;
	elif [ "$BOX86" = "wanted" ] && [ "$installed" != "$wanted" ];
			then apt-get purge box86-rpi4arm64 -y && apt-get install box86-rpi4arm64=$wanted;
	fi;
fi;

if [ "$BOX64" != "default" ];
then	installed="$(apt-cache policy box64-rpi4arm64 | grep Installed | awk '{print $2}')"
		wanted="$(apt-cache policy box64-rpi4arm64 | grep 500 | grep "$BOX64" | awk 'NR==1 {print $2}')"
		latest="$(apt-cache policy box64-rpi4arm64 | grep Candidate | awk '{print $2}')"

	if [ "$BOX64" = "latest" ] && [ "$installed" != "$latest" ];
			then apt-get purge box64-rpi4arm64 -y && apt-get install box64-rpi4arm64=$latest;
	elif [ "$BOX64" = "wanted" ] && [ "$installed" != "$wanted" ];
			then apt-get purge box64-rpi4arm64 -y && apt-get install box64-rpi4arm64=$wanted;
	fi;
fi;

if [ ! -f /valheim/start_server.sh ] || [ "$UPDATE" = "enabled" ] || [ "$UPDATE" = "1" ]; then

	steamcmd_dir=/data/steamcmd
	if [ ! -x "$steamcmd_dir/linux32/steamcmd" ]; then
		echo "Copying SteamCMD to $steamcmd_dir..."
		mkdir -p "$steamcmd_dir"
		cp -a /steamcmd/. "$steamcmd_dir/"
	fi
	cd "$steamcmd_dir"
	if [ ! -d /valheim ]; then
		echo "Creating /valheim directory..."
		mkdir -p /valheim
	fi
    echo "Updating the server..."

	if ! touch /valheim/.write-test 2>/dev/null; then
		echo "Valheim installation failed: /valheim is not writable"
		exit 1
	fi
	rm -f /valheim/.write-test
	available_kb=$(df -Pk /valheim | awk 'NR == 2 { print $4 }')
	if [ -z "$available_kb" ] || [ "$available_kb" -lt 3145728 ]; then
		echo "Valheim installation failed: /valheim needs at least 3 GiB free"
		exit 1
	fi

	export HOME="$steamcmd_dir"
	export LD_LIBRARY_PATH="$steamcmd_dir/linux32:$LD_LIBRARY_PATH"
	echo "Starting Valheim installation process..."
	installed=0
	for attempt in 1 2 3 4 5; do
		echo "Valheim installation attempt $attempt/5..."
		box86 ./linux32/steamcmd -nobootstrapupdate -tcp \
		+@sSteamCmdForcePlatformType linux \
		+force_install_dir /valheim \
		+login anonymous \
		+app_info_update 1 \
		+app_info_print 896660 \
		+app_update 896660 validate \
		+quit

		if [ -x /valheim/valheim_server.x86_64 ]; then
			installed=1
			break
		fi

		[ "$attempt" -lt 5 ] && sleep 5
	done

	if [ "$installed" -ne 1 ]; then
		echo "Valheim installation did not complete after 5 attempts"
	fi

fi

if [ ! -x /valheim/valheim_server.x86_64 ]; then
echo "Valheim installation failed: /valheim/valheim_server.x86_64 is missing"
exit 1
fi

# Manage Persistency
cp -f /scripts/start_server.sh.tpl	/valheim/start_server.sh

cd /valheim

#Pause Option
if [ $PAUSE = enabled ] || [ $PAUSE = 1 ]; then
mkdir -p /data/logs
cp /scripts/knockd.conf /etc/knockd.conf
sed -i s.START_KNOCKD=0.START_KNOCKD=1.g /etc/default/knockd
service knockd restart
chmod +x /scripts/pause.sh
(/scripts/pause.sh)&
fi

# Start Server
chmod +x ./start_server.sh
export LOG_FILE="/data/logs/valheim-$(date '+%d.%m.%y - %H:%M:%S').log"
touch $LOG_FILE
echo "$LOG_FILE" > /data/logs/log-link.txt
./start_server.sh 2>/dev/null | tee -a "$LOG_FILE"
sleep 600
