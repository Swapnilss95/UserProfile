import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _bgDeep = Color(0xFF080C14);
const Color _bgCard = Color(0xFF0F1624);
const Color _bgSurface = Color(0xFF141E2E);
const Color _accentA = Color(0xFF00D4AA);
const Color _accentB = Color(0xFF00A86B);
const Color _textPrimary = Color(0xFFE8F0FE);
const Color _textSecondary = Color(0xFF8899B0);
const Color _textMuted = Color(0xFF4A5A72);


class RequestsPage extends StatelessWidget {

  const RequestsPage({super.key});


  Color statusColor(String status) {

    switch(status){

      case "Accepted":
      case "Success":
        return _accentB;

      case "Declined":
      case "Failed":
        return Colors.redAccent;

      default:
        return Colors.orangeAccent;
    }

  }



  String formatDate(dynamic value){

    if(value == null){
      return "Just now";
    }

    if(value is Timestamp){

      return DateFormat(
        "dd MMM yyyy, hh:mm a"
      ).format(value.toDate());

    }

    return "N/A";
  }



  Future<void> deleteRequest(
      BuildContext context,
      String id
      ) async {


    try{

      await FirebaseFirestore.instance
          .collection("requests")
          .doc(id)
          .delete();


      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text("Request deleted"),
          backgroundColor: _accentB,
        ),
      );


    }catch(e){

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );

    }

  }



  void deleteDialog(
      BuildContext context,
      String id
      ){

    showDialog(
      context: context,
      builder: (ctx){

        return AlertDialog(

          backgroundColor: _bgCard,

          title: const Text(
            "Delete Request?",
            style: TextStyle(
              color:_textPrimary
            ),
          ),


          content: const Text(
            "Remove this order permanently?",
            style: TextStyle(
              color:_textSecondary
            ),
          ),


          actions:[

            TextButton(
              onPressed: (){
                Navigator.pop(ctx);
              },
              child: const Text(
                "Cancel"
              ),
            ),


            TextButton(

              onPressed: (){

                Navigator.pop(ctx);

                deleteRequest(
                    context,
                    id
                );

              },

              child: const Text(
                "Delete",
                style:TextStyle(
                  color:Colors.red
                ),
              ),

            )

          ],

        );

      },
    );

  }





  @override
  Widget build(BuildContext context) {


    final user =
        FirebaseAuth.instance.currentUser;



    return Scaffold(

      backgroundColor:_bgDeep,


      appBar:AppBar(

        backgroundColor:_bgCard,

        title:const Text(
          "My Order Requests",
          style:TextStyle(
            color:_textPrimary
          ),
        ),

      ),



      body:user==null

      ? const Center(
        child:Text(
          "Please login",
          style:TextStyle(
            color:_textSecondary
          ),
        ),
      )


      : StreamBuilder<QuerySnapshot>(


        stream:FirebaseFirestore.instance
            .collection("requests")
            .where(
              "userId",
              isEqualTo:user.uid
        )
            .orderBy(
              "createdAt",
              descending:true
        )
            .snapshots(),


        builder:(context,snapshot){


          if(snapshot.hasError){

            return Center(

              child:Text(
                snapshot.error.toString(),
                style:
                const TextStyle(
                    color:Colors.red
                ),
              ),

            );

          }



          if(snapshot.connectionState ==
              ConnectionState.waiting){

            return const Center(
              child:CircularProgressIndicator(
                color:_accentA,
              ),
            );

          }



          final docs =
              snapshot.data?.docs ?? [];



          if(docs.isEmpty){

            return const Center(

              child:Text(
                "No requests found",
                style:TextStyle(
                    color:_textSecondary
                ),
              ),

            );

          }





          return ListView.builder(

            itemCount:docs.length,

            itemBuilder:(context,index){


              final doc =
                  docs[index];


              final data =
                  doc.data()
                  as Map<String,dynamic>;



              final items =
                  List.from(
                      data["items"] ?? []
                  );



              final status =
                  data["orderStatus"]
                      ?.toString()
                      ??
                      "Pending Approval";



              return Card(

                color:_bgCard,

                margin:
                const EdgeInsets.all(12),


                child:ExpansionTile(


                  iconColor:_textSecondary,

                  collapsedIconColor:
                  _textSecondary,



                  title:Row(

                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,


                    children:[


                      Text(

                        "₹${data["totalAmount"] ?? 0}",

                        style:
                        const TextStyle(
                          color:_textPrimary,
                          fontWeight:
                          FontWeight.bold,
                        ),

                      ),



                      Row(

                        children:[

                          Text(
                            status,
                            style:TextStyle(
                              color:
                              statusColor(status),
                            ),
                          ),


                          IconButton(

                            onPressed:(){

                              deleteDialog(
                                context,
                                doc.id,
                              );

                            },

                            icon:
                            const Icon(
                              Icons.delete,
                              color:
                              Colors.redAccent,
                            ),

                          )

                        ],

                      )

                    ],

                  ),




                  subtitle:Column(

                    crossAxisAlignment:
                    CrossAxisAlignment.start,


                    children:[

                      Text(
                        "Txn: ${data["transactionRef"] ?? "N/A"}",
                        style:
                        const TextStyle(
                          color:_textSecondary,
                        ),
                      ),


                      Text(
                        formatDate(
                          data["createdAt"],
                        ),
                        style:
                        const TextStyle(
                          color:_textMuted,
                        ),
                      ),


                    ],

                  ),





                  children:[


                    Container(

                      color:_bgSurface,


                      child:Column(

                        children:


                        items.map<Widget>((e){


                          final item =
                              Map<String,dynamic>
                              .from(e);



                          return ListTile(

                            leading:
                            item["image"] != null

                            ? Image.network(
                              item["image"],
                              width:45,
                              height:45,
                              fit:BoxFit.cover,
                            )

                            : const Icon(
                              Icons.shopping_bag,
                              color:_textSecondary,
                            ),



                            title:Text(

                              item["title"] ??
                              "Product",

                              style:
                              const TextStyle(
                                color:_textPrimary,
                              ),

                            ),



                            subtitle:Text(

                              "${item["area"] ?? ""} sq ft",

                              style:
                              const TextStyle(
                                color:_textSecondary,
                              ),

                            ),



                            trailing:Text(

                              item["cost"] ??
                              "₹0",

                              style:
                              const TextStyle(
                                color:_accentA,
                              ),

                            ),

                          );


                        }).toList(),

                      ),

                    )

                  ],

                ),

              );

            },

          );

        },

      ),

    );

  }

}