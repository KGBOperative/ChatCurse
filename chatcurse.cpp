/*
 *  Author: Amandeep Gill
 *  File: chatcurse.cpp
 *  File Contents: currently contains the main menu and functions to start either 
 *      a client or server session
 */
#include <iostream>
#include <cstring>
#include <string>
#include <sys/socket.h>
#include <netdb.h>
#include <unistd.h>
#include <errno.h>
#include <sstream>

#define DEBUG false
#define debug if (DEBUG) std::cout

// creates a client socket, asks for server to connect to
// * if connection is successful: send user msg to server, and display result from server
// * throws error if errno is set
void setup_client() throw(const char*);

// creates a server socket, listens for client connections
// * if socket setup is successful: recieve client msg and send back the number of bytes
//      recieved, as well as the recieved msg
// * throws error if errno is set on socket creation/binding
void setup_server() throw(const char*);

// main() also serves as the main menu
// currently asks user to start either a server or client connection
int main() {
    std::cout << "Welcome to ChatCurse!" << std::endl;
    do {
        std::string make_server;
        std::cout << "Start server? [yN]: ";
        std::getline(std::cin, make_server);

        // user selected default or typed something starting with n or N
        // indicates that user would like to connect to a server as a client
        if (make_server == "" || tolower(make_server[0]) == 'n') {
            try {
                std::cout << "Setting up client" << std::endl;
                setup_client();
            } catch (const char *err) {
                std::cout << "Error: " << err << std::endl;
            }
        }

        // user typed something starting with a y or Y
        // indicates that the user would like to start a char server
        else if (tolower(make_server[0]) == 'y') {
            try {
                std::cout << "Setting up server" << std::endl;
                setup_server();
            } catch (const char *err) {
                std::cout << "Error: " << err << std::endl;
            }
        }
        
        // user did not type a valid input
        // tell user that the option typed was unknown
        else {
            std::cout << "Unknown option: " << make_server << std::endl;
        }

        // ask user to quit or continue
        // quit if user types something starting with q or Q
        std::string quit;
        //std::cin.ignore(1000, '\n');
        std::cout << "Enter 'q' to quit: ";
        std::getline(std::cin, quit);

        if (tolower(quit[0]) == 'q')
            return 0;

    } while (true);

    return 0;
}


void setup_client() throw(const char*) {
    int status;

    // setup the structs for handling the host info
    struct addrinfo host_info;
    struct addrinfo *host_info_list;
    memset(&host_info, 0, sizeof host_info);
    host_info.ai_family = AF_UNSPEC;
    host_info.ai_socktype = SOCK_STREAM;

    // query user for the server to connect to
    std::string server_addr;
    std::cout << "Please enter the host address: ";
    std::cin >> server_addr;
    std::cin.ignore(1000, '\n');
    status = getaddrinfo(server_addr.c_str(), "5555", &host_info, &host_info_list);
    
    if (status != 0) 
        throw (gai_strerror(status));

    // setup the client socket
    int socketfd;
    socketfd = socket(host_info_list->ai_family, host_info_list->ai_socktype, host_info_list->ai_protocol);
    if (socketfd == -1) 
        throw (strerror(errno));

    // connect the host socket
    status = connect(socketfd, host_info_list->ai_addr, host_info_list->ai_addrlen);
    if (status == -1) 
        throw (strerror(errno));

    // client is connected to the server
    // read msg from client and wait for server response
    std::cout << "Successfully connected to " << server_addr << std::endl;
    std::cout << "type ':quit' to disconnect from server" << std::endl;
    do {
        std::cout << "client> ";
        std::string msg = "";
        std::getline(std::cin, msg);

        debug << "sending '" << msg << "'" << std::endl;
        // shut down socket and leave function if user enters ':quit'
        if (msg == ":quit") {
            std::cout << "shutting down client" << std::endl;

            freeaddrinfo(host_info_list);
            close(socketfd);
            return;
        }

        // send the msg and wait for server response
        int len;
        ssize_t bytes_sent;
        len = msg.length();
        bytes_sent = send(socketfd, msg.c_str(), len, 0);

        if (bytes_sent < 0)
            throw (strerror(errno));

        // get reply from server
        ssize_t bytes_recieved;
        char *recv_msg = new char[1000];
        bytes_recieved = recv(socketfd, recv_msg, 1000, 0);

        if (bytes_recieved == 0 || bytes_recieved == -1) 
            throw (strerror(errno));

        // hack to clean up what we recieved
        recv_msg[bytes_recieved] = '\0';
        std::string server_msg(recv_msg);
        delete[] recv_msg;

        // print reply to the screen
        std::cout << server_addr << "> " << server_msg << std::endl;
    } while (true);
}

void setup_server() throw(const char*) {
    do {
        // setup the structs for handling the host info
        int status;
        struct addrinfo host_info;
        struct addrinfo *host_info_list;

        memset(&host_info, 0, sizeof host_info);

        // tell the host that we are a server listening for clients
        host_info.ai_family = AF_UNSPEC;
        host_info.ai_socktype = SOCK_STREAM;
        host_info.ai_flags = AI_PASSIVE;
        status = getaddrinfo(NULL, "5555", &host_info, &host_info_list);

        // setup listening socket
        int socketfd;
        socketfd = socket(host_info_list->ai_family, host_info_list->ai_socktype, host_info_list->ai_protocol);
        if (socketfd == -1) 
            throw (strerror(errno));

        // bind the socket to the specified port
        int yes = 1;
        status = setsockopt(socketfd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int));
        status = bind(socketfd, host_info_list->ai_addr, host_info_list->ai_addrlen);
        if (status == -1) 
            throw (strerror(errno));

        // wait for a client to successfully connect
        std::cout << "Waiting for connection from client" << std::endl;

        // currently listening for only one client at a time
        status = listen(socketfd, 1);

        if (status == -1) 
            throw (strerror(errno));
        
        // attempt connection to incoming client
        int client_sockfd;
        struct sockaddr_storage client_addr;
        socklen_t addr_size = sizeof(client_addr);
        client_sockfd = accept(socketfd, (struct sockaddr *)&client_addr, &addr_size);

        if (client_sockfd == -1) 
            throw (strerror(errno));

        // client successfully connected, attempt to retrieve the hostname of the client
        // use unknown_client if hostname or address is not available
        struct hostent *client = gethostbyaddr((struct sockaddr *)&client_addr, 16, PF_INET);
        std::string client_name;
        if (client != NULL)
            client_name = client->h_name;
        else
            client_name = "unknown_client";

        std::cout << "Successfully establihsed connection with " << client_name << std::endl;
        std::cout << "Waiting for messages" << std::endl;

        // recieve msgs from client until connection is closed
        do {
            // read in msg from client
            ssize_t bytes_recieved;
            char *recv_msg = new char[1000];
            bytes_recieved = recv(client_sockfd, recv_msg, 1000, 0);

            // client connection closed, break out of loop and start again
            if (bytes_recieved == 0) {
                std::cout << "connection to " << client_name << " closed" << std::endl;
                delete[] recv_msg;
                break;
            }

            else if (bytes_recieved == -1) {
                delete[] recv_msg;
                throw (strerror(errno));
            }

            // hack to clean up what the server recieved
            std::string client_msg(recv_msg);

            // print msg from client to the console
            std::cout << client_name << "> " << client_msg << std::endl;
            
            // respond to client with the length of the message and the message itself
            std::stringstream response("");;
            response << "msg len = " << bytes_recieved << "; msg = '" << client_msg << "'";
            int res_len = response.str().length();
            int bytes_sent = send(client_sockfd, response.str().c_str(), res_len, 0);
            response.flush();
        } while (true);

        // shut down the server
        freeaddrinfo(host_info_list);
        close(socketfd);
        close(client_sockfd);

        std::cout << "shutting down server" << std::endl;
    } while (true);
}
