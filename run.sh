!/bin/sh

#定义每月10日结算

jiesuanri=10

#定义监控流量，单位GB

jiankongGB=400

#换算成byte

jiankongby=$[$jiankongGB1024102410248]

#监控网络接口

eth=eth1

#读取当前网络流量

rece=cat /proc/net/dev | grep $eth | awk '{print $2}'
tran=cat /proc/net/dev | grep $eth | awk '{print $10}'

#定义数据文件，dayfile指每天流量统计数据，monfile指每结算周期流量统计数据，logfile为杀掉shadowsocks进程的日志文件

dayfile="liuliang_day"
monfile="liuliang_mon"
logfile="liuliang_log"

#获取当前时间

curdate=date "+%F %T"

#获取当月天数

curday=date +%d

#初始化写入数据：日期 接收量 流出量 日期 接收量 流出量 总计接收量 总计流出量

inital="$curdate $rece $tran $curdate $rece $tran 0 0\n"

#切换至用户目录

cd ~

#测试并生成文件，写入初始数据

if [ ! -e $dayfile ] || [ ! -e $monfile ]
then
printf "$inital" > $dayfile
printf "$inital" > $monfile
exit
fi

#读取每天流量统计文件的最后一行

predayarr=(awk 'END {print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10}' $dayfile)

#获取初始日期天数

bgday=date -d ${predayarr[0]} +%d

#获取初始流量

predayrece=${predayarr[6]}
predaytran=${predayarr[7]}

#计算当前流量与初始流量差额

dayrececha=$[$rece-$predayrece]
daytrancha=$[$tran-$predaytran]

#读取结算周期流量统计文件最后一行

premonarr=(awk 'END {print $1,$2,$3,$4,$9,$10}' $monfile)

#判断流量差额是否为正数，为正数则将文件中总流量与差额相加，为负数则将文件中总流量与当前流量相加

if (($daytrancha>=0))
then
daysumrece=$[${predayarr[8]}+$dayrececha]
daysumtran=$[${predayarr[9]}+$daytrancha]
monsumrece=$[${premonarr[4]}+$dayrececha]
monsumtran=$[${premonarr[5]}+$daytrancha]
else
daysumrece=$[${predayarr[8]}+$rece]
daysumtran=$[${predayarr[9]}+$tran]
monsumrece=$[${premonarr[4]}+$rece]
monsumtran=$[${premonarr[5]}+$tran]
fi

#删除每天流量统计文件最后一行

sed -i '$d' $dayfile

#更新每天流量统计文件

printf "${predayarr[0]} ${predayarr[1]} ${predayarr[2]} ${predayarr[3]} $curdate $rece $tran $daysumrece ${daysumtran}\n" >> $dayfile

#判断是否跨天，若是则初始化新一天的数据

if (($curday!=$bgday))
then
printf "$inital" >> $dayfile
fi

#删除结算周期统计文件最后一行

sed -i '$d' $monfile

#更新结算周期统计文件

printf "${premonarr[0]} ${premonarr[1]} ${premonarr[2]} ${premonarr[3]} $curdate $rece $tran $monsumrece ${monsumtran}\n" >> $monfile

#判断是否到了结算日，若是则初始化新结算周期数据

if (($curday==$jiesuanri))
then
printf "$inital" >> $monfile
fi

#计算流入流出数据总量

sumliuliang=$[$monsumrece+$monsumtran]

#判断是否超出监管流量，若是则杀掉shadowsocks进程，并写入日志文件

if (($sumliuliang>=$jiankongby))
then
printf "$curdate Jiankong:$jiankongby Qujian:${premonarr[0]} ${premonarr[1]} - $curdate Reve:$recesum Tran:${transum}\n" >> $logfile
kill -9 ps -ef | grep shadowsocks | grep -v grep | awk '{print $2}' >> $logfile 2>&1

fi

