import std.socket;
import std.stdio;

class Buffer{
    ubyte[] buffer;
    Socket net;
    Address other;

    bool host;
    bool connected;

    this(bool host, string oip, ushort bindport){
      this.host = host;
      net = new Socket(AddressFamily.INET, SocketType.DGRAM);
      net.blocking = false;
      net.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
      net.bind(new InternetAddress(bindport));

      other = new InternetAddress(oip, bindport);
    }

    ~this(){
      if(connected){
        //other.close();
        net.shutdown(SocketShutdown.BOTH);
        net.close();
      }
    }

    static enum PacketType{
        Player    =10, //Player position
        PData     =11, //Score, lives
        Bullets   =21, //Bullet data
        Asteroids =22, //Asteroids data
        GameStart =30, //
        GameOver  =31, //When 1 player dies
        NoData    =99 //Empty packet
    }

    void listen(){
        // long bytesRead;
        // try{
        //     //other = net.accept();
        //     connected = true;
        //     net.blocking = false;
        // }catch(SocketAcceptException e){
        //     writeln(e);
        //     return; //Return if no client waiting to connect
        // }
    }

    void connect(string ip, ushort port){
      // try{
      // net.connect(new InternetAddress(ip, port));
      // }catch(SocketOSException e){
      //   return;
      // }
      // connected = true;
      // net.blocking = false;
    }

    ubyte[] receive(){
      ubyte[1024] recv;
      long got = net.receiveFrom(recv, SocketFlags.NONE, other);
      if(got < 1){ //No packet was sent
          return [99];
      }
      connected = true;
      return recv[0..got].dup;
    }

    void startPacket(PacketType t){
        buffer ~= t & 0xff;
    }
    void flush(string ip, ushort port){
      writeln("SEND:",buffer);
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
    void add(string s){
      for(int i = 0; i < 4; i++){
        buffer ~= i<s.length?s[i]:0;
      }
    }
    void pad(ushort bytes){
      for(ushort i=0;i<bytes;i++){
        buffer ~= 0;
      }
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
