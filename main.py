# pip install python-dotenv langchain langchain-community langchain-chroma chromadb pypdf groq sentence-transformers langchain-huggingface
from langchain_chroma.vectorstores import Chroma
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_core.prompts import ChatPromptTemplate
from dotenv import load_dotenv
from groq import Groq
import os

load_dotenv()

CAMINHO_DB = "db"

prompt_template = """
Responda a pergunta do usuário:
{pergunta} 

com base nessas informações abaixo:

{base_conhecimento}"""

def perguntar():
    pergunta = input("Escreva sua pergunta: ")

    # carregar o banco de dados
    funcao_embedding = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
    db = Chroma(persist_directory=CAMINHO_DB, embedding_function=funcao_embedding)

    # comparar a pergunta do usuario (embedding) com o meu banco de dados
    resultados = db.similarity_search_with_relevance_scores(pergunta, k=4)
    if len(resultados) == 0 or resultados[0][1] < 0.2:
        print("Não conseguiu encontrar alguma informação relevante na base")
        return
    
    textos_resultado = []
    for resultado in resultados:
        texto = resultado[0].page_content
        textos_resultado.append(texto)
    
    base_conhecimento = "\n\n----\n\n".join(textos_resultado)
    prompt = ChatPromptTemplate.from_template(prompt_template)
    prompt_formatado = prompt.invoke({"pergunta": pergunta, "base_conhecimento": base_conhecimento})
    
    # Usar Groq com Llama
    client = Groq(api_key=os.getenv("GROQ_API_KEY"))
    completion = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[
            {
                "role": "user",
                "content": prompt_formatado.to_string()
            }
        ],
        temperature=1,
        max_completion_tokens=1024,
        top_p=1,
        stream=True,
        stop=None
    )

    print("Resposta da IA: ", end="")
    for chunk in completion:
        print(chunk.choices[0].delta.content or "", end="")
    print()  # Nova linha ao final

perguntar()