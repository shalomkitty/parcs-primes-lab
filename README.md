# Лабораторна 1 — PARCS-Python + Google Cloud

Тема: паралельний підрахунок простих чисел у діапазоні `[2, N]`.

У проєкті тільки один файл з алгоритмом — `solution.py`. PARCS-Python запускає клас `Solver` на master-вузлі та викликає `@expose`-метод `count_primes()` на віддалених воркерах. Порівнюються 1, 2 і 4 воркери.

## Файли

- `solution.py` — послідовна та паралельна реалізації, вимірювання часу.
- `input.txt` — число `2000000` (верхня межа діапазону).
- `cloud/run_parcs.sh` — запускає PARCS (master + обрана кількість воркерів).
- `cloud/stop_parcs.sh` — зупиняє контейнери.
- `tests/test_solution.py` — три локальні тести (без встановлення PARCS).
- `report/Звіт.md` — звіт з таблицею для фактичних вимірювань.

## 1. Google Cloud: створити VM

Потрібні Google Cloud-проєкт із підключеним billing та встановлений [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) на локальному комп'ютері. Команди нижче зручно виконувати з термінала (PowerShell, Linux або macOS).

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud services enable compute.googleapis.com
gcloud compute instances create parcs-lab \
  --zone=us-central1-a \
  --machine-type=e2-standard-4 \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=20GB
```

## 2. Встановити Docker на VM

```bash
gcloud compute ssh parcs-lab --zone=us-central1-a
```

У терміналі VM:

```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
exit
```

Скопіювати сценарій на VM, перебуваючи в корені проєкту на локальному комп'ютері:

```bash
gcloud compute scp cloud/run_parcs.sh parcs-lab:~/run_parcs.sh --zone=us-central1-a
```

## 3. Запустити PARCS з одним воркером

```bash
gcloud compute ssh parcs-lab --zone=us-central1-a
bash run_parcs.sh 1
sudo docker ps
exit
```

Для доступу до вебінтерфейсу на локальному комп'ютері відкрийте інший термінал та залиште його запущеним:

```bash
gcloud compute ssh parcs-lab --zone=us-central1-a -- -N -L 8080:127.0.0.1:8080
```

Відкрийте у браузері: <http://localhost:8080>

У розділі **Nodes / Workers** переконайтеся, що під'єднано рівно одного воркера (реєстрація може зайняти кілька секунд). У розділі Add Job:

1. Job Name: `primes-1`;
2. Solution File: `solution.py`;
3. Input File: `input.txt`;
4. Натисніть **Add**.

У Jobs* дочекайтеся завершення та завантажте Output. Збережіть як `result-1.txt`.

Очікувана правильна відповідь при N = 2 000 000: `prime_count=148933`.

## 4. Повторити для 2 та 4 воркерів

У терміналі VM:

```bash
bash run_parcs.sh 2
```

Зачекайте, поки в Nodes відобразяться 2 воркери, повторно надішліть ті самі `solution.py` та `input.txt`, скачайте Output як `result-2.txt`.

Потім аналогічно:

```bash
bash run_parcs.sh 4
```

Збережіть Output як `result-4.txt`. Якщо CLI перебував на комп'ютері, а не в SSH-сесії VM, перед цими командами зайдіть через `gcloud compute ssh ...`.

Для надійніших замірів запустіть кожну конфігурацію тричі та обчисліть середнє. В усіх запусках N має бути однаковим; не запускайте сторонні навантаження на VM. `run_parcs.sh` перезапускає master, тож історія попередніх jobs у вебінтерфейсі зникає: зберігайте Output перед перемиканням.

## 5. Як читати Output

```text
N=2000000
workers=4
prime_count=148933
sequential_seconds=...
parallel_seconds=...
speedup=...
efficiency=...
```

- `sequential_seconds` — час підрахунку всього діапазону на master.
- `parallel_seconds` — час від надсилання задач воркерам до отримання результатів.
- `speedup` — `sequential_seconds / parallel_seconds`.
- `efficiency` — `speedup / workers` (від 0 до 1 за звичайних умов; може бути >1 через варіативність вимірювань).

Час реєстрації воркерів і старту job у `parallel_seconds` не входить. Загальну тривалість job додатково можна побачити на сторінці Jobs.

## 6. Локальні перевірки

Python 3.9+ потрібен лише для тестів, **не** для PARCS runtime:

```bash
python3 -m unittest discover -s tests -v
```

Тести підставляють прості локальні заглушки замість Pyro4, перевіряють коректність алгоритму, поділ діапазону та формат вихідних даних. Це **не замінює** перевірку на реальній хмарній системі.


