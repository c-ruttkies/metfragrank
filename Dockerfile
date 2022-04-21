FROM openjdk:11

ADD casmi2016.tgz /

WORKDIR /usr/local/bin/
ADD run.sh .

RUN apt-get update && \
	apt-get install -y bc parallel && \
	chmod u+x run.sh && \
	wget -q https://github.com/ipb-halle/MetFragRelaunched/releases/download/v2.4.8/MetFragCommandLine-2.4.8.jar && \
	ln -s MetFragCommandLine-2.4.8.jar MetFragCommandLine.jar && \
	wget -q https://github.com/c-ruttkies/Tools/raw/master/MetFragTools-2.4.8.jar && \
	ln -s MetFragTools-2.4.8.jar MetFragTools.jar

ENTRYPOINT ["run.sh"]
