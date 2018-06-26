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

/*
int main()
{
    string input;
    string y;
    string a;
    string v;

    // Take inputs to determine which instructions to call
    while(true) 
    {
        cout << "Enter instrunctions: ";
        cin >> input;
        if (input == "done")
        {
            break;
        }
        if (input == "next")
        {
            next();
        }
        if (input == "restore")
        {
            restore();
        }
        if (input == "powerdown")
        {
            powerdown();
        }
        if (input == "movepose")
        {
            cout << "Enter the pose: ";
            cin >> y;
            cout << "Enter the acceleration: ";
            cin >> a;
            cout << "Enter the velocity: ";
            cin >> v;
            stringstream temp1(a);
            float acceleration = 0;
            temp1 >> acceleration;
            stringstream temp2(v);
            float velocity = 0;
            temp2 >> velocity;
            move_pose(y, acceleration, velocity);
        }
        if (input == "movejoints")
        {
            cout << "Enter the joints: ";
            cin >> y;
            cout << "Enter the acceleration: ";
            cin >> a;
            cout << "Enter the velocity: ";
            cin >> v;
            stringstream temp1(a);
            float acceleration = 0;
            temp1 >> acceleration;
            stringstream temp2(v);
            float velocity = 0;
            temp2 >> velocity;
            move_joints(y, acceleration, velocity);
        }
        if (input == "linearx")
        {
            cout << "Enter the distance: ";
            cin >> y;
            cout << "Enter the acceleration: ";
            cin >> a;
            cout << "Enter the velocity: ";
            cin >> v;
            stringstream temp1(a);
            float acceleration = 0;
            temp1 >> acceleration;
            stringstream temp2(v);
            float velocity = 0;
            temp2 >> velocity;
            stringstream temp3(y);
            float distance = 0;
            temp3 >> distance;
            linear_x(distance, acceleration, velocity);
        }
        if (input == "lineary")
        {
            cout << "Enter the distance: ";
            cin >> y;
            cout << "Enter the acceleration: ";
            cin >> a;
            cout << "Enter the velocity: ";
            cin >> v;
            stringstream temp1(a);
            float acceleration = 0;
            temp1 >> acceleration;
            stringstream temp2(v);
            float velocity = 0;
            temp2 >> velocity;
            stringstream temp3(y);
            float distance = 0;
            temp3 >> distance;
            linear_y(distance, acceleration, velocity);
        }
        if (input == "linearz")
        {
            cout << "Enter the distance: ";
            cin >> y;
            cout << "Enter the acceleration: ";
            cin >> a;
            cout << "Enter the velocity: ";
            cin >> v;
            stringstream temp1(a);
            float acceleration = 0;
            temp1 >> acceleration;
            stringstream temp2(v);
            float velocity = 0;
            temp2 >> velocity;
            stringstream temp3(y);
            float distance = 0;
            temp3 >> distance;
            linear_z(distance, acceleration, velocity);
        }
    }
    return 0;
}
*/

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
