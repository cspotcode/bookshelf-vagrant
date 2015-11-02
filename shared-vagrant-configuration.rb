Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu/trusty64'

  config.vm.provision 'shell', privileged: false, inline: <<-EOF
    # Prevent package installation from asking questions; use defaults.
    export DEBIAN_FRONTEND=noninteractive

    # Set an initial MySQL password; normally provided at an interactive password prompt during installation.
    sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password asdf"
    sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password asdf"

    # Install distribution-provided packages.
    sudo apt-get update
    sudo apt-get install --quiet --assume-yes #{PACKAGES.join(' ')}

    # Remove MySQL root password
    mysql -uroot -pasdf -e "SET PASSWORD FOR root@localhost=PASSWORD('');"

    # Create MySQL database if it doesn't already exist.
    mysql -u '#{DB_CONFIG['mysql']['user']}' \
      <<< 'CREATE DATABASE IF NOT EXISTS #{DB_CONFIG['mysql']['database']}'

    # Configure PostgreSQL to allow passwordless login for all users.
    sudo bash -c "echo 'local all all     trust' >  /etc/postgresql/*/main/pg_hba.conf"
    sudo bash -c "echo 'host  all all all trust' >> /etc/postgresql/*/main/pg_hba.conf"
    sudo service postgresql restart

    # Create PostgreSQL database if it doesn't already exist.
    psql --username=postgres --list --quiet --tuples-only \
      | cut --delimiter='|' --fields=1 \
      | grep --quiet --word-regexp '#{DB_CONFIG['postgres']['database']}' \
      || createdb --username='#{DB_CONFIG['postgres']['user']}' '#{DB_CONFIG['postgres']['database']}'

    # Install Node JS and NPM using nvm
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.29.0/install.sh | bash
    eval "`cat ~/.bashrc`"
    nvm install '#{NODE_VERSION}'
    nvm use '#{NODE_VERSION}'
    nvm alias default '#{NODE_VERSION}'

    # Install Node modules, and ensure native extensions are compiled for Linux.
    cd /vagrant
    npm install
    npm rebuild
  EOF
end
