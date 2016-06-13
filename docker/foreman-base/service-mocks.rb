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

  def status
    if @resource[:status]   # PostgreSQL
      super
    else
      return :running
    end
  end

  def startcmd
    if @resource[:status]   # PostgreSQL
      super
    else
      ["/bin/true"]
    end
  end

  def stopcmd
    if @resource[:status]   # PostgreSQL
      super
    else
      ["/bin/true"]
    end
  end
end
