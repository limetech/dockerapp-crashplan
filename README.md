docker-crashplan
================

This is a Dockerfile setup for CrashPlan - https://www.crashplan.com

To run:

docker run -d --net="bridge" --name=crashplan -v /path/to/your/config:/config -v /mnt/user:/data -v /etc/localtime:/etc/localtime:ro -p 4242:4242 -p 8080:8080 limetech/crashplan
