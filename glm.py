from zhipuai import ZhipuAI

print("Iniciando o script...")

client = ZhipuAI(api_key="7e3fc4d6e6b94a20a2ac828b3d3cda05.x4D5GmaJjIp7eIAw") 

response = client.chat.completions.create(
    model="glm-5.2",  # Substitua pelo nome exato do seu modelo (ex: glm-4.5)
    messages=[
        {"role": "user", "content": "Escreva uma função em Python para um jogo de empurrar jogadores."}
    ],
)
print(response.choices[0].message.content)