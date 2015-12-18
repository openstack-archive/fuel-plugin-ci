set switch_ip [lindex $argv 0]
set switch_pass [lindex $argv 1]

     spawn ssh "root@$switch_ip"
     set timeout 500
     expect "yes/no" {
     send "yes\r"
     expect "*?assword" { send "$switch_pass\r" }
     } "*?assword" { send "$switch_pass\r" }
     expect "# " { send "show run" }
     expect "# " { send "exit\r" }