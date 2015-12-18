$fuel_iso_path='/var/lib/iso'
$jenkins_slave='jenkins-slave.test-company.org'
$fuel_remote_iso_path='/var/lib/iso'
[ -d $fuel_iso_path ] || mkdir $fuel_iso_path
last_rel=$(w3m -dump -cols 400 https://www.fuel-infra.org/release/status#tab_2 | grep -v community-8 | grep "ok    ok      ok    ok" | head -1 | cut -d' ' -f 8)
rel=$last_rel
if [ ! -f "$fuel_iso_path/$rel.iso" ]; then
    touch "$fuel_iso_path/$rel.iso.progress"
    aria2c -x10 http://seed.fuel-infra.org/fuelweb-iso/$rel.iso -d $fuel_iso_path -l $fuel_iso_path/$rel.iso.progress
    echo "http://seed.fuel-infra.org/fuelweb-iso/$rel.iso -b -o $fuel_iso_path$rel.iso.progress -P $fuel_iso_path"
fi

# make sure that previous finished successfully, if not, delete the directory that have been created for it
    grep -i "error" $fuel_iso_path/$rel.iso.progress
    res=$(echo $?)
    if [ "$res" -eq 0 ]; then
        # this means we had an error in it, delete folder created, then exit with error
        echo "error has been detected while downloading this build.. check the above progress file."
        rm -rf $fuel_iso_path
        exit 1
    fi
    pathToIso="$fuel_iso_path/$rel.iso"
fi

rsync -av --progress --delete $fuel_iso_path $jenkins_slave:$fuel_remote_iso_path

exit 0