#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#   File: chatcurse.nim
#   Author: Amandeep Gill
#   Contents: rewrite of the chatcurse basic client/server setup in Nimrod
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

# library imports
import sockets, strutils

proc setupClient()
proc setupServer()

# main procedure, serves as the main menu to allow the user to setup either a
#   client or a server connection, or to exit gracefully
proc main(): int =
    echo "Welcome to Chat Curse!"

    while True:
        while True:
            # ask user to start either a server or client
            write(stdout, "Start server? [yN]: ")
            case readLine(stdin)[0]
            of 'n', 'N':
                # run procedure to start a connection to chat server
                setupClient()
                break
            of 'y', 'Y':
                # run procedure to accept client requests
                setupServer()
                break
            of 'q':
                # exit program
                return 0
            else: echo "Invalid input"
        
        # ask user whether or not to continue the program
        write(stdout, "Quit program? [Yn]: ")
        case readLine(stdin)[0]
        of 'n', 'N': continue
        of 'y', 'Y': break
        else: echo "Invalid input\n"

    return 0

discard main()

# setup client procedure
#   accepts: nothing
#   returns: nothing
#   purpose: asks the user to supply a username and server address. allows the
#       user to send messages to, and recieve messages from, the server until
#       the command is read to terminate the connection
proc setupClient() =
    # prompt user for their username
    write(stdout, "Enter your username: ")
    let clientName = readLine(stdin)

    # initialize the client socket
    var client = socket()
    
    var server: string = ""
    while True:
        # prompt user for the server to connect to
        write(stdout, "Enter the host name or address to connect to: ")
        server = readLine(stdin)

        # attempt to connect to the server provided, catch any error thrown
        # by the connect proc
        try:
            client.connect(server, TPort(5555))
            break
        except EOS:
            let
              ex = getCurrentException()
              xmsg = getCurrentExceptionMsg()
            echo "Error ", repr(ex), ": ", xmsg
        except:
            echo "Uknown exception thrown"

    # send the user's username to the server
    client.send(clientName & "\r\L")
    echo "Type :quit :q to disconnect from server"

    # read in the string to send to the server or quit if the command is read
    while True:
        write(stdout, clientName, "> ")
        let str = readLine(stdin)

        echo "sending msg = ", str

        if str == ":quit" or str == ":q":
            client.close
            return

        try:
            client.send(str & "\r\L")
            echo "msg sent"
        except:
            let
              ex = getCurrentException()
              xmsg = getCurrentExceptionMsg()
            echo "Error ", repr(ex), ": ", xmsg
            break

        var msg: string = ""
        client.readLine(msg)

        if msg == "":
            echo server, " has closed the connection"
            break
        echo server, "> ", msg

    setupClient()

proc setupServer() =
    var server = socket()
    try:
        server.bindAddr(TPort(5555), "127.0.0.1")
    except:
        let
          ex = getCurrentException()
          xmsg = getCurrentExceptionMsg()
        echo "Error ", repr(ex), ": ", xmsg
        return

    server.listen(1)

    while True:
        var client = socket()
        server.accept(client)
        
        echo "client connection on ", $client.getFD

        var clientName: string = ""
        client.readLine(clientName)
        echo "client ", clientName, " has connected"

        while True:
            var msg: string = ""
            client.readLine(msg)
            
            if msg == "":
                echo clientName, " has disconnected"
                break

            echo clientName, "> ", msg

            try:
                client.send("len = " & $msg.len & ", msg = " & msg & "\r\L")
            except:
                let
                  ex = getCurrentException()
                  xmsg = getCurrentExceptionMsg()
                echo "Error ", repr(ex), ": ", xmsg
                break
