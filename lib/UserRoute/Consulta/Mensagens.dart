import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pidv1/Classes/Mensagem.dart';


class Mensagens extends StatefulWidget {
  String id;
  String nome;
  String foto;

  Mensagens(this.id, this.foto, this.nome);

  @override
  _MensagensState createState() => _MensagensState();
}

class _MensagensState extends State<Mensagens> {

  bool _subindoImagem = false;
  String _idUsuarioLogado ="";
  String _idUsuarioDestinatario = "";
  FirebaseFirestore db = FirebaseFirestore.instance;
  TextEditingController _controllerMensagem = TextEditingController();

  _enviarMensagem() {
    String textoMensagem = _controllerMensagem.text;
    if (textoMensagem.isNotEmpty) {
      Mensagem mensagem = Mensagem();
      mensagem.idUsuario = _idUsuarioLogado;
      mensagem.mensagem = textoMensagem;
      mensagem.urlImagem = "";
      mensagem.tipo = "texto";
      mensagem.data = Timestamp.now().toString();

      //Salvar mensagem para remetente
      _salvarMensagem(_idUsuarioLogado, _idUsuarioDestinatario, mensagem);

      //Salvar mensagem para o destinatário
      _salvarMensagem(_idUsuarioDestinatario, _idUsuarioLogado, mensagem);

      //Salvar conversa


    }
  }


  _salvarMensagem(
      String idRemetente, String idDestinatario, Mensagem msg) async {
    await db
        .collection("mensagens")
        .doc(idRemetente)
        .collection(idDestinatario)
        .add(msg.toMap());

    //Limpa texto
    _controllerMensagem.clear();

  }

  Future _enviarFoto() async {

    XFile imagemSelecionada;
    final ImagePicker _picker = ImagePicker();
    imagemSelecionada = (await _picker.pickImage(source: ImageSource.gallery) )! ;

    _subindoImagem = true;
    String nomeImagem = DateTime.now().millisecondsSinceEpoch.toString();
    FirebaseStorage storage = FirebaseStorage.instance;
    Reference pastaRaiz = storage.ref();
    Reference arquivo = pastaRaiz
        .child("mensagens")
        .child( _idUsuarioLogado )
        .child( nomeImagem + ".jpg");

    //Upload da imagem
    UploadTask task = arquivo.putFile( File(imagemSelecionada.path));

    //Controlar progresso do upload
    task.snapshotEvents.listen((TaskSnapshot storageEvent){

      if( storageEvent.state == TaskState.running ){
        setState(() {
          _subindoImagem = true;
        });
      }else if( storageEvent.state == TaskState.success ){
        setState(() {
          _subindoImagem = false;
        });
      }

    });

    //Recuperar url da imagem
    task.whenComplete(() => null).then((TaskSnapshot snapshot){
      _recuperarUrlImagem(snapshot);
    });
    ;

  }

  Future _recuperarUrlImagem(TaskSnapshot snapshot) async {

    String url = await snapshot.ref.getDownloadURL();

    Mensagem mensagem = Mensagem();
    mensagem.idUsuario = _idUsuarioLogado;
    mensagem.mensagem = "";
    mensagem.urlImagem = url;
    mensagem.tipo = "imagem";
    mensagem.data = Timestamp.now().toString();

    //Salvar mensagem para remetente
    _salvarMensagem(_idUsuarioLogado, _idUsuarioDestinatario, mensagem);

    //Salvar mensagem para o destinatário
    _salvarMensagem(_idUsuarioDestinatario, _idUsuarioLogado, mensagem);

  }



  _recuperarDadosUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    User? usuarioLogado = await auth.currentUser;
    setState(() {
      _idUsuarioLogado = usuarioLogado!.uid;

      _idUsuarioDestinatario = widget.id;
    });

  }

  @override
  void initState() {
    super.initState();
    _recuperarDadosUsuario();
  }

  @override
  Widget build(BuildContext context) {

    var caixaMensagem = Container(
      padding: EdgeInsets.all(8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: TextField(
                controller: _controllerMensagem,
                autofocus: true,
                keyboardType: TextInputType.text,
                style: TextStyle(fontSize: 20),
                decoration: InputDecoration(
                    contentPadding: EdgeInsets.fromLTRB(32, 8, 32, 8),
                    hintText: "Digite uma mensagem...",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(32)),
                    prefixIcon:
                    _subindoImagem
                        ? CircularProgressIndicator()
                        : IconButton(icon: Icon(Icons.camera_alt), onPressed:(){_enviarFoto(); } //_enviarFoto

                    )
                ),
              ),
            ),
          ),
          FloatingActionButton(
            backgroundColor: Colors.lightBlueAccent,
            child: Icon(
              Icons.send,
              color: Colors.white,
            ),
            mini: true,
            onPressed: _enviarMensagem,
          )
        ],
      ),
    );

    var stream = StreamBuilder(
      stream: db
          .collection("mensagens")
          .doc(_idUsuarioLogado)
          .collection(_idUsuarioDestinatario)
      .orderBy("data",descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return Center(
              child: Column(
                children: <Widget>[
                  Text("Carregando mensagens"),
                  CircularProgressIndicator()
                ],
              ),
            );
            break;
          case ConnectionState.active:
          case ConnectionState.done:

            QuerySnapshot? querySnapshot = snapshot.data as QuerySnapshot?;

            if (snapshot.hasError) {
              return Expanded(
                child: Text("Erro ao carregar os dados!"),
              );
            } else {
              return Expanded(
                child: ListView.builder(
                    itemCount: querySnapshot!.docs.length,
                    itemBuilder: (context, indice) {

                      //recupera mensagem
                      List<DocumentSnapshot> mensagens = querySnapshot.docs.toList();
                      DocumentSnapshot item = mensagens[indice];

                      double larguraContainer =
                          MediaQuery.of(context).size.width * 0.8;

                      //Define cores e alinhamentos
                      Alignment alinhamento = Alignment.centerRight;
                      Color cor = Color(0xffd2ffa5);
                      if ( _idUsuarioLogado != item["idUsuario"] ) {
                        alinhamento = Alignment.centerLeft;
                        cor = Colors.blueAccent;
                      }

                      return Align(
                        alignment: alinhamento,
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Container(
                            width: larguraContainer,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: cor,
                                borderRadius:
                                BorderRadius.all(Radius.circular(8))),
                            child:
                            item["tipo"] == "texto"
                                ? Text(item["mensagem"],style: TextStyle(fontSize: 18),)
                                : Image.network(item["urlImagem"]),
                          ),
                        ),
                      );
                    }),
              );
            }

            break;
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            CircleAvatar(
                maxRadius: 20,
                backgroundColor: Colors.blueAccent,
                backgroundImage: widget.foto != null
                    ? NetworkImage(widget.foto)
                    : null),
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(widget.nome),
            )
          ],
        ),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("pictures/backgroundDoc.png"), fit: BoxFit.cover)),
        child: SafeArea(
            child: Container(
              padding: EdgeInsets.all(8),
              child: Column(
                children: <Widget>[
                  stream,
                  caixaMensagem,
                ],
              ),
            )),
      ),
    );
  }
}