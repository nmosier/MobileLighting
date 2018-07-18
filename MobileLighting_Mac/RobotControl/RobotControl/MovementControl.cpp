#include <unistd.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <string>
#include <arpa/inet.h>
#include <iostream>
#include <sstream>
#include "MovementControl.h"

#define PORT0 30000
#define PORT1 30002
using namespace std;

int client()
{
    // SOCKET CONNECTION ON PORT 30001
    int sock = 0;
    struct sockaddr_in serv_addr;
    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0)
    {
        printf("\n Socket creation error \n");
        return -1;
    }
  
    memset(&serv_addr, '0', sizeof(serv_addr));
  
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(PORT1);
      
    // Convert IPv4 and IPv6 addresses from text to binary form
    if(inet_pton(AF_INET, "140.233.20.115", &serv_addr.sin_addr)<=0) 
    {
        printf("\nInvalid address/ Address not supported \n");
        return -1;
    }
  
    if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0)
    {
        printf("\nConnection Failed \n");
        return -1;
    }
    return sock;
}

extern "C" void sendscript(char *script) {
    int client_sock = client();
    int result = send(client_sock, script, strlen(script), 0);
    if (result < 0) {
        printf("\nSending failed.\n");
    }
}
 
int restore()
{
    int client_sock;
    client_sock = client();
    
    char original[1024] = "movel(p[0.253382,-0.0770761,0.410262,-1.99486,-0.096691,-1.87748], a = 0.5, v = 0.5)\n";
    int result;
    result = send(client_sock, original, 1024, 0);
    if (result < 0) {
        printf("\nSending Failed\n");
    }

    return 0;
}

int next()
{
    int client_sock;
    client_sock = client();
    char next[1024] = "movel(p[0.455506,-0.0263883,0.405709,-2.08937,0.139225,-2.01385], a = 0.5, v = 0.5)\n";
    int result;

    result = send(client_sock, next, 1024, 0);
    if (result < 0) {
        printf("\nSending Failed\n");
    }

    return 0;
}

int powerdown()
{
    int client_sock;
    client_sock = client();
    char next[1024] = "powerdown()\n";
    int result;

    result = send(client_sock, next, 1024, 0);
    if (result < 0) {
        printf("\nSending Failed\n");
    }

    return 0;
}

int move_pose(string pose, float a, float v)
{
    int client_sock;
    client_sock = client();
    string s;
    int result;

    s = "movel(" + pose + ", a = " + to_string(a) + ", v = " + to_string(v) + ")\n";
    printf("%s\n",s.c_str());
    int n = s.length(); 
    char command[n+1]; 
    strcpy(command, s.c_str());

    result = send(client_sock, command, n+1, 0);
    if (result < 0) {
        printf("\nSending Failed\n");
    }
    return 0;
}   

int move_joints(string pose, float a, float v)
{
    int client_sock;
    client_sock = client();
    string s;
    int result;

    s = "movej([" + pose + "], a = " + to_string(a) + ", v = " + to_string(v) + ")\n";
    printf("%s\n",s.c_str());
    int n = s.length(); 
    char command[n+1]; 
    strcpy(command, s.c_str());

    result = send(client_sock, command, n+1, 0);
    if (result < 0) {
        printf("\nSending Failed\n");
    }
    return 0;
}  

int linear_x(float d, float a, float v)
{
    int client_sock;
    client_sock = client();
    string s;
    int result;

    s = "def Pose():\nCurPos = get_actual_tcp_pose()\nDisplacement = p[0.0,0.0," + to_string(d) + ",0.0,0.0,0.0]\nTarget = pose_trans(CurPos, Displacement)\nmovej(Target, a = " + to_string(a) + ", v = " + to_string(v) + ")\nend\n";
    printf("%s\n",s.c_str());
    int n = s.length(); 
    char command[n+1]; 
    strcpy(command, s.c_str());

    result = send(client_sock, command, n+1, 0);
    if (result < 0) {
        printf("\nSending Failed\n");
    }
    return 0;
} 

int linear_y(float d, float a, float v)
{
    int client_sock;
    client_sock = client();
    string s;
    int result;

    s = "def Pose():\nCurPos = get_actual_tcp_pose()\nDisplacement = p[0.0," + to_string(d) + ",0.0,0.0,0.0,0.0]\nTarget = pose_trans(CurPos, Displacement)\nmovej(Target, a = " + to_string(a) + ", v = " + to_string(v) + ")\nend\n";
    printf("%s\n",s.c_str());
    int n = s.length(); 
    char command[n+1]; 
    strcpy(command, s.c_str());

    result = send(client_sock, command, n+1, 0);
    if (result < 0) {
        printf("\nSending Failed\n");
    }
    return 0;
} 

int linear_z(float d, float a, float v)
{
    int client_sock;
    client_sock = client();
    string s;
    int result;

    s = "def Pose():\nCurPos = get_actual_tcp_pose()\nDisplacement = p[" + to_string(d) + ",0.0,0.0,0.0,0.0,0.0]\nTarget = pose_trans(CurPos, Displacement)\nmovej(Target, a = " + to_string(a) + ", v = " + to_string(v) + ")\nend\n";
    printf("%s\n",s.c_str());
    int n = s.length(); 
    char command[n+1]; 
    strcpy(command, s.c_str());

    result = send(client_sock, command, n+1, 0);
    if (result < 0) {
        printf("\nSending Failed\n");
    }
    return 0;
}
