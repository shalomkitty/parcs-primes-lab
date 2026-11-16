# Лабораторна робота №1 — PARCS-Python + Google Cloud

**Тема:** паралельне чисельне інтегрування методом середніх прямокутників.

Потрібно наближено обчислити число π за визначеним інтегралом:

\[
\pi = \int_0^1 \frac{4}{1+x^2}\,dx.
\]

Проєкт порівнює послідовний алгоритм на `parcs-lab` (master) із паралельним виконанням на **1, 2 та 4 окремих worker-VM** у Google Cloud. Алгоритм реалізовано в `solution.py` для PARCS-Python (Python 2.7, Pyro4).




## 1. Локальна підготовка (WSL)

У Windows відкрийте VS Code та термінал Ubuntu/WSL:

```bash
cd /mnt/c/Users/artem/Desktop/parcs-primes-lab
code .
```


У `input.txt` має бути **одне додатне ціле число** — кількість кроків інтегрування. Для порівняння продуктивності можна використати:

```text
50000000
```


Перевір тести локально:

```bash
python3 -m unittest discover -s tests -v
```

Тести перевіряють точність наближення π, покриття індексів без пропусків, повний цикл із 4 фіктивними воркерами та некоректне значення `N=0`.

## 2. Перевір авторизацію Google Cloud

Виконайте усі команди `gcloud` нижче в **локальному WSL**:

```bash
gcloud auth list
gcloud config get-value project
gcloud compute instances list
```

Наявна VM `parcs-lab` використовується як master. Скрипт автоматично визначає її зону, VPC і приватну IP-адресу. Якщо потрібно явно вказати зону, використовуйте `ZONE=us-central1-a` перед командою.

**Перед початком:** у хмарному проєкті мають бути увімкнені Compute Engine API та billing, а квота повинна дозволяти чотири додаткові VM. Compute Engine та диски можуть бути платними.

## 3. Запуск PARCS із 1, 2 та 4 воркерами

### Один воркер

У локальному WSL:

```bash
bash cloud/run_parcs.sh 1
```

Скрипт налаштовує master на `parcs-lab` та запускає одну окрему worker-VM. На початковому запуску Docker може ще встановлюватися. Перевірити наявність VM:

```bash
gcloud compute instances list
```

У **другому локальному терміналі WSL** відкрийте SSH-тунель (тримайте його активним під час роботи):

```bash
gcloud compute ssh parcs-lab --zone=us-central1-a -- \
  -N -L 8080:127.0.0.1:8080
```

У браузері Windows відкрийте **http://localhost:8080** і зайдіть до вкладки **Nodes**. Створюйте завдання лише після того, як видно потрібну кількість активних воркерів.

На вкладці **Add Job**:

1. `Job Name`: наприклад, `integration-1-run1`.
2. `Solution File`: новий `solution.py`.
3. `Input File`: `input.txt` з однаковим N для всіх запусків.
4. Натисніть **Add** і збережіть Output після завершення.

### Два та чотири воркери

Перед перемиканням збережіть Output попередніх Jobs. Потім **у локальному WSL**:

```bash
bash cloud/run_parcs.sh 2

bash cloud/run_parcs.sh 4
```

Скрипт перезапускає master, тому попередні Jobs можуть зникати з інтерфейсу. Для кожного `p=1,2,4` проведіть **три окремі запуски** з тим самим N, щоб згодом обчислити середній час.

## 4. Формат вихідного файлу

Після виконання `solution.py` повертає Output приблизно такої структури (числа часу нижче **не наведені**, їх треба отримати запуском):

```text
N=50000000
workers=4
approx_pi=<обчислене значення>
absolute_error=<похибка наближення>
sequential_seconds=<час, с>
parallel_seconds=<час, с>
speedup=<прискорення>
efficiency=<ефективність як частка>
```

- `approx_pi` — обчислене значення інтеграла; має бути близьким до `3.141592653589793`.
- `absolute_error` — `abs(approx_pi - math.pi)`; що менше, то точніше.
- `sequential_seconds` — час обчислення всього інтеграла на master.
- `parallel_seconds` — час віддаленого виконання та отримання результатів із воркерів.
- `speedup` — відношення `sequential_seconds / parallel_seconds`.
- `efficiency` — `speedup / workers`; у відсотках множ на 100.


## 5. Перевірка та діагностика

Список VM:

```bash
gcloud compute instances list
```

Після `bash cloud/run_parcs.sh 4` очікуються `parcs-lab` і чотири `parcs-workerN` у стані `RUNNING`. Перевірте контейнери на master та окремому worker:

```bash
gcloud compute ssh parcs-lab --zone=us-central1-a --command='sudo docker ps'
gcloud compute ssh parcs-worker2 --zone=us-central1-a --command='sudo docker ps'
```

Перевірте логи worker2:

```bash
gcloud compute ssh parcs-worker2 --zone=us-central1-a \
  --command='sudo docker logs --tail 50 parcs-worker'
```

Якщо Job показує `workers=1`, хоча очікується 4, спочатку подивись вкладку **Nodes**. Кількість запущених VM сама по собі не гарантує, що всі воркери зареєструвалися в master. `Registered to master` і активні вузли підтверджують їх підключення.

## 6. Зупинка хмарних ресурсів

Після роботи, **у локальному WSL**:

```bash
bash cloud/stop_parcs.sh
```

Зупиняються всі п’ять VM, але їхні диски не видаляються і можуть тарифікуватися. Повністю видаляй VM лише тоді, коли більше не потрібні результати або конфігурація проєкту.

