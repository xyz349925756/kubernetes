This is the docker tab auto-completion file, because using the binary installation of docker and then installing bash-completion does not have the completion function, you need these two files, so I uploaded these two files to this directory for those who can not use docker completion.

这个是docker tab自动补全文件，因为使用二进制安装的docker再安装bash-completion没有补全功能，需要这两个文件，所以我把这两个文件上传到此目录供不能使用docker 补全的朋友们使用。


使用方法：
yum -y install bash-completion bash-completion-extras

cp /server/soft/docker*   /usr/share/bash-completion/completions/

source /etc/profile.d/bash_completion.sh

[root@master03 ~]# docker 
attach     cp         history    load       pause      restart    service    tag        wait
build      create     image      login      plugin     rm         stack      top        
builder    diff       images     logout     port       rmi        start      trust      
commit     events     import     logs       ps         run        stats      unpause    
config     exec       info       manifest   pull       save       stop       update     
container  export     inspect    network    push       search     swarm      version    
context    help       kill       node       rename     secret     system     volume     
[root@master03 ~]# docker-compose 
build    create   exec     kill     port     push     run      stop     up       
bundle   down     help     logs     ps       restart  scale    top      version  
config   events   images   pause    pull     rm       start    unpause  
