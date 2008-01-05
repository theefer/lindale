
class Xmms::Client
  def add_to_qt4_mainloop()
    @qt4ml = XmmsQt4.new(self)
    @qt4ml.bind
  end
end

class XmmsQt4 < Qt::Object

  slots 'onRead()', 'onWrite()'

  def initialize(xclient)
    super()

    @conn = xclient
  end

  def bind()
    @rsock = Qt::SocketNotifier.new(@conn.io_fd, Qt::SocketNotifier::Read)
    @wsock = Qt::SocketNotifier.new(@conn.io_fd, Qt::SocketNotifier::Write)

    connect(@rsock, SIGNAL('activated(int)'), self, SLOT('onRead()'))
    connect(@wsock, SIGNAL('activated(int)'), self, SLOT('onWrite()'))

    @rsock.setEnabled(true)
    @wsock.setEnabled(false)

    @conn.io_on_need_out {|flag| @wsock.setEnabled(flag == 1)}
  end

  def onRead()
    # FIXME: raise exception if returns false?
    @conn.io_in_handle
  end

  def onWrite()
    # FIXME: raise exception if returns false?
    @conn.io_out_handle
  end
end
