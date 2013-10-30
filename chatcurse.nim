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
when isMainModule:
    block main:
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
                    break main
                else: echo "Invalid input"
            
            # ask user whether or not to continue the program
            write(stdout, "Quit program? [Yn]: ")
            case readLine(stdin)[0]
            of 'n', 'N': continue
            of 'y', 'Y': break main
            else: echo "Invalid input\n"

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
        # wait for the user to enter a string of text
        write(stdout, clientName, "> ")
        let str = readLine(stdin)

        # check if the user wants to quit
        if str == ":quit" or str == ":q":
            client.close
            return

        # attempt to send the msg to the server
        try:
            client.send(str & "\r\L")
        except:
            let
              ex = getCurrentException()
              xmsg = getCurrentExceptionMsg()
            echo "Error ", repr(ex), ": ", xmsg
            break

        # read response from server
        var msg: string = ""
        client.readLine(msg)

        # the connection has closed if the line read is empty
        if msg == "":
            echo server, " has closed the connection"
            break
        # print the response from the server if the msg is valid
        echo server, "> ", msg

    # retry connecting to the server if the connection fails
    setupClient()

# setup server procedure
#   accepts: nothing
#   returns: nothing
#   purpose: sets up a listening server and echos messages back to any clients
#       connected to the server
proc setupServer() =
    # create the server socket and bind it to the local address with port 5555
    var server = socket()
    try:
        server.bindAddr(TPort(5555), "127.0.0.1")
    except:
        let
          ex = getCurrentException()
          xmsg = getCurrentExceptionMsg()
        echo "Error ", repr(ex), ": ", xmsg
        return

    echo "Server created, waiting for connections"

    # set server socket to listen for 1 client at a time
    server.listen(1)

    while True:
        echo "Waiting for client connection"

        # accept incoming client connection
        var client = socket()
        server.accept(client)
        
        # grab username of the connected client
        var clientName: string = ""
        client.readLine(clientName)
        echo "client ", clientName, " has connected"

        # continue to accept messages from client until connection is dropped
        while True:
            # wait for client to send a message
            var msg: string = ""
            client.readLine(msg)
            
            # the client has disconnected if the line is empty
            if msg == "":
                echo clientName, " has disconnected"
                break

            # print the username and the message recieved
            echo clientName, "> ", msg

            # attempt to echo the length and message back to the client
            try:
                client.send("len = " & $msg.len & ", msg = " & msg & "\r\L")
            except:
                let
                  ex = getCurrentException()
                  xmsg = getCurrentExceptionMsg()
                echo "Error ", repr(ex), ": ", xmsg
                break
