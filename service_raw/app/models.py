from sqlalchemy.orm import (
    DeclarativeBase, 
    Mapped, 
    mapped_column
)
from sqlalchemy import (
    String
)


class Base(DeclarativeBase):
    pass


class Nickname(Base):
    __tablename__ = "nickname"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True, nullable=False)
    nick: Mapped[str] = mapped_column(String, nullable=False)