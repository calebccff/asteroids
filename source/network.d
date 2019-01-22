import std.socket;
import std.stdio;

//import std.parallelism : task, Task, taskPool;

class Buffer{
    ubyte[] buffer;
    ubyte[1024] recv;
    Socket net;
    Socket other;

    bool host;
    bool connected;

    this(bool host, ushort bindport){
        this.host = host;
        net = new Socket(AddressFamily.INET, SocketType.STREAM);
        if(host){
          net.blocking = false;
          net.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
          net.bind(new InternetAddress(bindport));
          net.listen(1);
        }
    }

    ~this(){
        other.close();
        net.shutdown(SocketShutdown.BOTH);
        net.close();
    }

    static enum PacketType{
        Player    =0x10,
        Objects   =0x20,
        GameStart =0x30,
        GameOver  =0x40
    }

    void listen(){
        long bytesRead;
        try{
            other = net.accept();
            connected = true;
        }catch(SocketAcceptException e){
            return; //Return if no client waiting to connect
        }
    }

    void connect(string ip, ushort port){
      net.connect(new InternetAddress(ip, port));
      connected = true;
      net.blocking = false;
    }

    void receive(){
      writeln("TEST");
      auto got = net.receive(recv);
      writeln(got, ": ", recv[0..got]);
      recv = new ubyte[1024];
    }

    void startPacket(PacketType t){
        buffer ~= t & 0xff;
    }
    void flush(){
      writeln("Sent: ", buffer);
      other.send(buffer);
      buffer = [];
    }
    void add(int i){
      buffer ~= (i >> 24) & 0xff;
      buffer ~= (i >> 16) & 0xff;
      buffer ~= (i >> 8 ) & 0xff;
      buffer ~= (i      ) & 0xff;
    }
}
