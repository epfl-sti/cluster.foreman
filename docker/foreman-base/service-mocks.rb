Puppet::Type.type(:service).provide :systemd, :parent => :base do
  desc "Mock `systemd` service provider."

  def status
    return :running
  end

  def startcmd
    ["/bin/true"]
  end

  def stopcmd
    ["/bin/true"]
  end
end

Puppet::Type.type(:service).provide :debian, :parent => :init do
  desc "Mostly-mock `debian` service provider."

  def must_actually_run_during_docker_build
    @resource[:name].match(/postgres/i)
  end

  def status
    if must_actually_run_during_docker_build
      super
    else
      return :running
    end
  end

  def startcmd
    if must_actually_run_during_docker_build
      super
    else
      ["/bin/true"]
    end
  end

  def stopcmd
    if must_actually_run_during_docker_build
      super
    else
      ["/bin/true"]
    end
  end

  def restartcmd
    if must_actually_run_during_docker_build
      super
    else
      nil
    end
  end

end
