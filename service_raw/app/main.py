from concurrent import futures
import grpc

from nicknames import nickname_pb2       # тут у нас messages
from nicknames import nickname_pb2_grpc  # тут - services

from .db import Session 
from .models import Nickname 

from sqlalchemy import select


class NicknameService(nickname_pb2_grpc.NicknameServiceServicer):
    def GetNickname(self, request, context):
        id_to_find = request.id
        with Session() as s:
            query = select(Nickname).where(Nickname.id==id_to_find)
            result = s.execute(query).scalar_one_or_none()
            if not result:
                context.abort(grpc.StatusCode.NOT_FOUND, "Пользователь по данному id не найден")
                
            return nickname_pb2.GetNicknameResponse(
                nickname=nickname_pb2.Nickname(id=result.id, nick=result.nick)
            )

    def ListNicknames(self, request, context):
        with Session() as s:
            query = select(Nickname)
            results = s.execute(query).scalars().all()
            
            return nickname_pb2.ListNicknamesResponse(
                nicknames=[
                    nickname_pb2.Nickname(id=n.id, nick=n.nick) for n in results
                ]
            )

def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    nickname_pb2_grpc.add_NicknameServiceServicer_to_server(NicknameService(), server)
    server.add_insecure_port("[::]:8000")
    server.start()
    print("gRPC server listening on :8000")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()