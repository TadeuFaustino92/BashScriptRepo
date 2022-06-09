The code is pretty self explanatory, but I'll give an insight.

This is my first ever script, I created it for automating a dull and painfull task that me and my team used to do at work. 
Every time a new system was planed to be deployed, we had to validate our own infrastructure and report it. Although very simple and straight forward, it was very time consuming, so I decided to automate it.

It basically consists of running 10 functions dependig on the server it's validating.
The first step is the data input provided by whomever is running the script, DataEntry.sh will get all information, propagate it and connect into servers remotely.
The second step is the infrastructure validation, once it's completed, it'll generate a report file per server and return it to the host.
