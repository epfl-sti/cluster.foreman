# Class: epflsti::private::elk
#
# ELK : Elasticsearch, Logstash and Kibana
#
class epflsti::private::elk() {
  # https://www.elastic.co/guide/en/logstash/current/getting-started-with-logstash.html
  
  # https://www.elastic.co/guide/en/logstash/master/package-repositories.html
  yumrepo { 'logstash':
    ensure => present,
    descr => "Logstash repository for 1.4.x packages",
    baseurl => "http://packages.elasticsearch.org/logstash/1.4/centos",
    gpgcheck => 1,
    gpgkey => "https://packages.elasticsearch.org/GPG-KEY-elasticsearch",
  }

  # https://www.elastic.co/guide/en/elasticsearch/reference/current/setup-repositories.html
  yumrepo { 'elasticsearch':
    ensure => present,
    descr => "Elasticsearch repository for 1.5.x packages",
    baseurl => "http://packages.elasticsearch.org/elasticsearch/1.5/centos",
    gpgcheck => 1,
    gpgkey => "https://packages.elasticsearch.org/GPG-KEY-elasticsearch",
  }

  class { 'logstash': }
  logstash::configfile { 'configname':
    content => template('epflsti/logstash_config.conf.erb')
  }	
}
