FROM node:4.3.2

RUN apt-get update && apt-get install -y sqlite3 awscli curl unzip git && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/hirenj/aws-runbuild /aws-runbuild
RUN chmod +x /aws-runbuild/run_buildstep.sh

CMD ["/bin/bash", "-c", "'source ~/dev/aws-runbuild/.bash; export -f build; export RUNBUILDPATH; bash'"]