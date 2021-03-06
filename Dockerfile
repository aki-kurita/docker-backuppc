FROM debian:jessie

ENV DEBIAN_FRONTEND noninteractive
ENV TMP_CONFIG /backuppc_initial_config
ENV TMP_DATA /backuppc_initial_data
ENV PERSISTENT_CONFIG /etc/backuppc
ENV PERSISTENT_DATA /var/lib/backuppc
ENV STARTSCRIPT /usr/local/bin/dockerstart.sh

ADD startscript.sh $STARTSCRIPT

RUN \
    # Install packages \
    apt-get update -y && \
    echo 'backuppc backuppc/reconfigure-webserver multiselect apache2' | debconf-set-selections && \
    apt-get install -y debconf-utils backuppc supervisor && \

    # Configure package config to a temporary folder to be able to restore it when no config is present
    mkdir -p $TMP_CONFIG $TMP_DATA/.ssh && \
    mv $PERSISTENT_CONFIG/* $TMP_CONFIG && \
    mv $PERSISTENT_DATA/* $TMP_DATA && \

    # Disable ssh host key checking per default
    echo "host *"                       >> $TMP_DATA/.ssh/config && \
    echo "    StrictHostKeyChecking no" >> $TMP_DATA/.ssh/config && \

    # Disable basic auth for package generated config
    sed -i 's/Auth.*//g' $TMP_CONFIG/apache.conf && \
    sed -i 's/require valid-user//g'  $TMP_CONFIG/apache.conf && \

    # Display Backuppc on / rather than /backuppc
    sed -i 's/Alias \/backuppc/Alias \//' $TMP_CONFIG/apache.conf && \
    # This is required to load images on /
    sed -i "s/^\$Conf{CgiImageDirURL} =.*/\$Conf{CgiImageDirURL} = '\/image';/g" $TMP_CONFIG/config.pl && \

    # Remove host 'localhost' from package generated config
    sed -i 's/^localhost.*//g' $TMP_CONFIG/hosts && \

    # for openshift
    sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf && \
    sed -i "s/^\$Conf{BackupPCUserVerify} =.*/\$Conf{BackupPCUserVerify} = 0;/g" $TMP_CONFIG/config.pl && \
    chmod -R 777 /var/log && \
    chmod -R 777 /etc/supervisor && \
    chmod -R 777 /var/run && \
    chmod 4755 /usr/lib/backuppc/cgi-bin/index.cgi && \
    chmod 4755 /usr/share/backuppc/bin/* && \

    # Make startscript executable
    chmod ugo+x $STARTSCRIPT

ADD supervisor.conf /etc/supervisor/supervisord.conf

USER 106
EXPOSE 8080
VOLUME $PERSISTENT_DATA
VOLUME $PERSISTENT_CONFIG

cmd $STARTSCRIPT 
