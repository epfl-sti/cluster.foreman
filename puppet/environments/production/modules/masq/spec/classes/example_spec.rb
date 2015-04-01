require 'spec_helper'

describe 'masq' do
  context 'supported operating systems' do
    ['Debian', 'RedHat'].each do |osfamily|
      describe "masq class without any parameters on #{osfamily}" do
        let(:facts) {{
          :osfamily => osfamily,
          :kernel   => 'Linux'
        }}

        it { should compile.with_all_deps }

        it { should contain_class('masq::config') }
      end
    end
  end

  context 'unsupported operating system' do
    describe 'masq class without any parameters on Solaris/Nexenta' do
      let(:facts) {{
        :kernel          => 'SunOS'
      }}

      it { expect { should }.to raise_error(Puppet::Error, /SunOS is unsupported/) }
    end
  end
end
