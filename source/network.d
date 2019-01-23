import std.socket;
import std.stdio;

class Buffer{
    ubyte[] buffer;
    Socket net;
    Socket other;

    bool host;
    bool connected;

    this(bool host, ushort bindport){
        this.host = host;
        net = new Socket(AddressFamily.INET, SocketType.DGRAM);
        if(host){
          //net.blocking = false; //For testing
          net.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
          net.bind(new InternetAddress(bindport));
          //net.listen(1);
        }
    }

    ~this(){
      if(connected){
        other.close();
        net.shutdown(SocketShutdown.BOTH);
        net.close();
      }
    }

    static enum PacketType{
        Player    =10,
        Bullets   =21,
        Asteroids =22,
        GameStart =30,
        GameOver  =31,
        NoData    =99
    }

    void listen(){
        long bytesRead;
        try{
            //other = net.accept();
            connected = true;
            net.blocking = false;
        }catch(SocketAcceptException e){
            writeln(e);
            return; //Return if no client waiting to connect
        }
    }

    void connect(string ip, ushort port){
      try{
      net.connect(new InternetAddress(ip, port));
      }catch(SocketOSException e){
        return;
      }
      connected = true;
      net.blocking = false;
    }

    ubyte[] receive(){
      ubyte[1024] recv;
      long got = net.receive(recv);
      if(got < 1){ //No packet was sent
          return [99];
      }
      return recv[0..got].dup;
    }

    void startPacket(PacketType t){
        buffer ~= t & 0xff;
    }
    void flush(string ip, ushort port){
      //writeln(":",buffer);
      //other.send(buffer);
      net.sendTo(buffer, new InternetAddress(ip, port));
      buffer = [];
    }
    void add(int i){
      buffer ~= (i >> 24) & 0xff;
      buffer ~= (i >> 16) & 0xff;
      buffer ~= (i >> 8 ) & 0xff;
      buffer ~= (i      ) & 0xff;
    }
    static int conv2int(ubyte[] x){
      int i = 0;
      i = x[0] << 24 | i;
      i = x[1] << 16 | i;
      i = x[2] << 8  | i;
      i = x[3] << 0  | i;
      return i;
    }
}
