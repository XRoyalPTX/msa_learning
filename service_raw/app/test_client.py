import grpc                                                                                                                       
from nicknames import nickname_pb2, nickname_pb2_grpc                                                                             
                                                                                                                                
channel = grpc.insecure_channel("localhost:8000")                                                                                 
stub = nickname_pb2_grpc.NicknameServiceStub(channel)                                                                             
                                                                                                                                
r = stub.GetNickname(nickname_pb2.GetNicknameRequest(id=2001))                                                                       
print("id=2001:", r.nickname.id, r.nickname.nick)                                                                                    
                                                                                                                                
r = stub.ListNicknames(nickname_pb2.ListNicknamesRequest())                                                                       
print("total:", len(r.nicknames))                                                                                                 
for n in list(r.nicknames)[:3]:                                                                                                   
    print(n.id, repr(n.nick))