<?php
$root=dirname(__DIR__);$directory=$root.'/.tools/mysql-test';
$pdo=new PDO('mysql:host=127.0.0.1;port=33579;charset=utf8mb4','root','',[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
$actual=realpath($pdo->query('SELECT @@datadir')->fetchColumn());if($actual!==realpath($directory))throw new RuntimeException('Refusing non-test database server');
$password=bin2hex(random_bytes(24));
foreach(['pq_backend_tests','pq_install_tests']as$db)$pdo->exec('CREATE DATABASE IF NOT EXISTS `'.$db.'` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
$pdo->exec("CREATE USER IF NOT EXISTS 'pq_test'@'127.0.0.1' IDENTIFIED BY '$password'");$pdo->exec("ALTER USER 'pq_test'@'127.0.0.1' IDENTIFIED BY '$password'");
foreach(['pq_backend_tests','pq_install_tests']as$db)$pdo->exec("GRANT ALL PRIVILEGES ON `$db`.* TO 'pq_test'@'127.0.0.1'");
file_put_contents(__DIR__.'/database-test.json',json_encode(['host'=>'127.0.0.1','port'=>33579,'username'=>'pq_test','password'=>$password]));
echo "Dedicated loopback test databases configured.\n";
