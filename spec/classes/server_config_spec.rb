require 'spec_helper'

describe 'mongodb::server::config', :type => :class do
  let :facts do
    {
      :operatingsystem => 'Debian',
      :operatingsystemmajrelease => 8,
      :osfamily        => 'Debian',
      :root_home       => '/root',
    }
  end

  describe 'with default values' do
    let(:pre_condition) { "include mongodb::server" }

    it { is_expected.to compile.with_all_deps }

    it {
      is_expected.to contain_file('/etc/mongodb.conf').with({
        :mode   => '0644',
        :owner  => 'root',
        :group  => 'root'
      })
    }

    it { is_expected.to contain_file('/etc/mongodb.conf').with_content(/^dbpath=\/var\/lib\/mongo/) }
    it { is_expected.to contain_file('/etc/mongodb.conf').with_content(/bindIp\s=\s0\.0\.0\.0/) }
    it { is_expected.to contain_file('/etc/mongodb.conf').with_content(/^port = 29017$/) }
    it { is_expected.to contain_file('/etc/mongodb.conf').with_content(/^logappend=true/) }
    it { is_expected.to contain_file('/etc/mongodb.conf').with_content(/^logpath=\/var\/log\/mongo\/mongod\.log/) }
    it { is_expected.to contain_file('/etc/mongodb.conf').with_content(/^fork=true/) }

    it { is_expected.to contain_file('/root/.mongorc.js').with({ :ensure => 'absent' }) }
  end

  describe 'with absent ensure' do
    let(:pre_condition) { "class { 'mongodb::server': $ensure = absent, }" }

    it {
      is_expected.to contain_file('/etc/mongodb.conf').with({ :ensure => 'absent' })
    }

  end

  describe 'when specifying storage_engine' do
    let(:pre_condition) { "class { 'mongodb::server': $storage_engine = 'SomeEngine', }" }

    it {
      is_expected.to contain_file('/etc/mongodb.conf').with_content(/storage.engine:\sSomeEngine/)
    }
  end

  describe 'with specific bind_ip values and ipv6' do
    let(:pre_condition) { ["class mongodb::server { $config = '/etc/mongodb.conf' $dbpath = '/var/lib/mongo' $rcfile = '/root/.mongorc.js' $ensure = present $bind_ip = ['127.0.0.1', 'fd00:beef:dead:55::143'] $ipv6 = true }", "include mongodb::server"]}

    it {
      is_expected.to contain_file('/etc/mongodb.conf').with_content(/bindIp\s=\s127\.0\.0\.1\,fd00:beef:dead:55::143/)
      is_expected.to contain_file('/etc/mongodb.conf').with_content(/ipv6=true/)
    }
  end

  describe 'with specific bind_ip values' do
    let(:pre_condition) { ["class mongodb::server { $config = '/etc/mongodb.conf' $dbpath = '/var/lib/mongo' $rcfile = '/root/.mongorc.js' $ensure = present $bind_ip = ['127.0.0.1', '10.1.1.13']}", "include mongodb::server"]}

    it {
      is_expected.to contain_file('/etc/mongodb.conf').with_content(/bindIp\s=\s127\.0\.0\.1\,10\.1\.1\.13/)
    }
  end

  describe 'when specifying auth to true' do
    let(:pre_condition) { ["class mongodb::server { $config = '/etc/mongodb.conf' $auth = true $dbpath = '/var/lib/mongo' $rcfile = '/root/.mongorc.js' $ensure = present }", "include mongodb::server"]}

    it {
      is_expected.to contain_file('/etc/mongodb.conf').with_content(/^auth=true/)
      is_expected.to contain_file('/root/.mongorc.js')
    }
  end

  describe 'when specifying set_parameter value' do
    let(:pre_condition) { ["class mongodb::server { $config = '/etc/mongodb.conf' $set_parameter = 'textSearchEnable=true' $dbpath = '/var/lib/mongo' $rcfile = '/root/.mongorc.js' $ensure = present }", "include mongodb::server"]}

    it {
      is_expected.to contain_file('/etc/mongodb.conf').with_content(/^setParameter = textSearchEnable=true/)
    }
  end

  describe 'with journal:' do
    context 'on true with i686 architecture' do
      let(:pre_condition) { ["class mongodb::server { $config = '/etc/mongodb.conf' $dbpath = '/var/lib/mongo' $rcfile = '/root/.mongorc.js' $ensure = present $journal = true }", "include mongodb::server"]}
      let (:facts) { { :architecture => 'i686' } }

      it {
        is_expected.to contain_file('/etc/mongodb.conf').with_content(/^journal = true/)
      }
    end
  end

  # check nested quota and quotafiles
  describe 'with quota to' do

    context 'true and without quotafiles' do
      let(:pre_condition) { ["class mongodb::server { $config = '/etc/mongodb.conf' $dbpath = '/var/lib/mongo' $rcfile = '/root/.mongorc.js' $ensure = present $quota = true }", "include mongodb::server"]}
      it {
        is_expected.to contain_file('/etc/mongodb.conf').with_content(/^quota = true/)
      }
    end

    context 'true and with quotafiles' do
      let(:pre_condition) { <<-PP
        class { 'mongodb::server':
          quota      => true,
          quotafiles => 1,
        }
        PP
      }

      it { is_expected.to contain_file('/etc/mongodb.conf').with_content(/quota = true/) }
      it { is_expected.to contain_file('/etc/mongodb.conf').with_content(/quotaFiles = 1/) }
    end
  end

  context 'with syslog set true' do
    let(:pre_condition) { <<-PP
      class { 'mongodb::server':
        syslog  => true,
        logpath => false,
      }
      PP
    }

    it {
      is_expected.to contain_file('/etc/mongodb.conf').with_content(/syslog = true/)
    }

    context 'with logpath set too' do
      let(:pre_condition) { <<-PP
        class { 'mongodb::server':
          syslog  => true,
          logpath => '/var/log/mongo/mongod.log',
        }
        PP
      }

      it {
        expect { is_expected.to contain_file('/etc/mongodb.conf') }.to raise_error(Puppet::Error, /You cannot use syslog with logpath/)
      }
    end

  end

  describe 'with store_creds' do
    context 'true' do
      let(:pre_condition) { <<-PP
        class { 'mongodb::server':
          admin_password => 'password',
          admin_username => 'admin',
          auth => true,
          store_creds => true,
        }
        PP
      }

      it {
        is_expected.to contain_file('/root/.mongorc.js').
          with_ensure('present').
          with_owner('root').
          with_group('root').
          with_mode('0600').
          with_content(/db.auth\('admin', 'password'\)/)
      }
    end

    context 'false' do
      let(:pre_condition) { <<-PP
        class { 'mongodb::server':
          admin_password => 'password',
          admin_username => 'admin',
          auth => true,
          store_creds => false,
        }
        PP
      }

      it {
        is_expected.to contain_file('/root/.mongorc.js').with_ensure('absent')
      }
    end
  end

end
