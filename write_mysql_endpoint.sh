#!/bin/bash

echo "write something"
read test
file=./roles/wordpress/templates/wp-config.php.test
alL="define('DB_HOST', '${test}');"
echo $alL
first="$(grep "\'DB_HOST\'" $file)"
echo $first
sed -e "s/${first}/${alL}/g" $file | tee $file
