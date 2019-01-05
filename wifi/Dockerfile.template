ARG machine=%%RESIN_MACHINE_NAME%%

FROM resin/${machine}-debian:jessie

LABEL maintainer="greg.luto@gmail.com"
LABEL license="MIT"

RUN apt-get update --fix-missing && apt-get install -y \
    hostapd \
    dbus \
    net-tools \
    iptables \
    dnsmasq \
    net-tools \
    macchanger

# mitmproxy requires this env
ENV LANG en_US.UTF-8 

ADD hostapd.conf /etc/hostapd/hostapd.conf
ADD hostapd /etc/default/hostapd
ADD dnsmasq.conf /etc/dnsmasq.conf

ADD entrypoint.sh /root/entrypoint.sh
WORKDIR /root
ENTRYPOINT ["/root/entrypoint.sh"]
