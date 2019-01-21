import std.socket;
import std.stdio;

//import std.parallelism : task, Task, taskPool;

class Buffer{
    ubyte[] buffer;
    ubyte[] recv;
    Socket net;

    bool host;
    Address other;

    this(bool host, ushort bindport){
        this.host = host;
        net = new Socket(AddressFamily.INET, SocketType.STREAM);
        net.bind(new InternetAddress("localhost", 3333));
        net.listen(1);
        net.blocking = false;
    }

    ~this(){
        net.shutdown(SocketShutdown.BOTH);
        net.close();
    }

    enum PacketType{
        Player    =0x10,
        Objects   =0x20,
        GameStart =0x30,
        GameOver  =0x40   
    }

    void listen(){
        Socket client;
        
        long bytesRead;
        try{
            client = net.accept();
        }catch(SocketAcceptException e){
            return;
        }
        writeln(client.localAddress.toString);
        while((bytesRead = client.receive(recv)) > 0){
            writeln(recv);
            client.send(recv);
        }
        
        client.close();
        recv = [0];
    }

    void setOther(string ip, ushort port){
        other = new InternetAddress(ip, port);
    }

    void startPacket(PacketType t){
        buffer ~= t & 0xff;
    }
    void flush(){
        net.sendTo(buffer, other);
    }
    void add(int i){
        buffer ~= (i >> 24) & 0xff;
        buffer ~= (i >> 16) & 0xff;
        buffer ~= (i >> 8 ) & 0xff;
        buffer ~= (i      ) & 0xff;
    }
}