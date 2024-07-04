
class Number {
    public int number;
}
class CacheLine {
    public boolean old; // указывает какую первой удалять
    public boolean dirty; // 1 (true) => еще не записаны в память
    public boolean valid; // 0 (false) => кэш-линия свободна, 1 (true) => занята
    public String tag; // tag хранится в string
    public CacheLine() {
        this.old = false;
        this.dirty = false;
        this.valid = false;
        this.tag = new String();
    }
}

class CacheSet {
    public CacheLine line_1; // кэш-линия 1
    public CacheLine line_2; // кэш-линия 2

    public CacheSet() {
        this.line_1 = new CacheLine();
        this.line_2 = new CacheLine();
    }

    public boolean isCacheHit(String tag) {
        return (line_1.tag.equals(tag) &&  line_1.valid) ||
                (line_2.tag.equals(tag) && line_2.valid);
    }

    public void memAccess(String tag, int bytes, Number tacts, Number hits, boolean read) {

//        кэш-попадание:
        if (isCacheHit(tag)) { // такой тег есть => кэш-попадание

            hits.number += 1; // увеличиваем счетчик кэш-попаданий
            tacts.number += 7; // кэш-попадание => кэш отвечает за 6 тактов и на 7 получаем ответ
            if (read) {
                if (bytes <= 2) {// проверка сколько битов передаётся кэш -> цпу
                    tacts.number += 1; // если 1 или 2 байта (8 или 16 бит)
                } else {
                    tacts.number += 2; //  4 байта кэш -> цпу
                }
            }

            if (line_1.tag.equals(tag)) {
                line_1.old = false;
                if (line_2.valid) {
                    line_2.old = true;
                }
                if (read) {
                    line_1.dirty = true;
                }
            } else if (line_2.tag.equals(tag)) {
                line_2.old = false;
                if (line_1.valid) {
                    line_1.old = true;
                }
                if (read) {
                    line_2.dirty = true;
                }
            }

//            кэш - промах
        } else { // случился кэш-промах

            tacts.number += 4; // кэш посылает запрос к памяти MemCTR
            tacts.number += 100; // MemCTR отвечает за 100 тактов (здесь учитывается 1 такт - передача адреса по А2
            tacts.number += 8; // передается обратно по А2 по 2 байта поэтому CACHE_LINE_SIZE / 2 = 8

            if (line_1.valid && line_2.valid) {
                if (line_1.old) {
                    if (line_1.dirty) {
                        tacts.number += 100;
                        line_1.dirty = false;
                    }
                    line_1.tag = tag;
                    line_1.old = false;
                    line_2.old = true;
                } else if (line_2.old) {
                    if (line_2.dirty) {
                        tacts.number += 100;
                        line_2.dirty = false;
                    }
                    line_2.tag = tag;
                    line_2.old = false;
                    line_1.old = true;
                }
            } else if (!line_1.valid) {
                line_1.valid = true;
                line_1.old = false;
                line_1.tag = tag;
                if (read) {
                    line_1.dirty = true;
                } else {
                    line_1.dirty = false;
                }
                if (line_2.valid) {
                    line_2.old = true;
                }
            } else if (!line_2.valid) {
                line_2.valid = true;
                line_2.old = false;
                line_2.tag = tag;
                if (read) {
                    line_2.dirty = true;
                } else {
                    line_2.dirty = false;
                }
                line_1.old = true;
            }

            if (read) {
                if (bytes <= 2) {
                    tacts.number += 1;
                } else {
                    tacts.number += 2;
                }
            }
        }
    }
}

class Cache {
    public CacheSet[] sets = new CacheSet[64];

    public Cache() {
        for (int i = 0; i < 64; i++) {
            sets[i] = new CacheSet(); // создание кэша из 64 кэш-блоков
        }
    }

    public void memAccess (String address, int bytes, Number tacts, Number misses, boolean read_write) {
        int set = Integer.parseInt(address.substring(8, 14), 2);
        String tag = address.substring(0, 8);
        sets[set].memAccess(tag, bytes, tacts, misses, read_write);
    }
}
public class Main {
    public static String createAddress(int a) {
        StringBuilder address = new StringBuilder(Integer.toBinaryString(a));
        while (address.length() < 18) {
            address.insert(0, '0');
        }
        return address.toString();
    }
    public static void main(String[] args) {
        Cache cache = new Cache();

        Number tacts = new Number(); // счетчик тактов
        Number hits = new Number(); // счетчик попаданий
        int requests = 0; // счетчик обращений
        int M = 64;
        int N = 60;
        int K = 32;

        tacts.number += 3; // инициализация M, N, K
        int pa = 0;
        int pc = 5888;
        tacts.number += 2;

        for (int y = 0; y < M; y++) {
            tacts.number += 1;
            for (int x = 0; x < N; x++) {
                tacts.number += 1;

                int pb = 2048;
                tacts.number += 1;
                int s = 0;
                tacts.number += 1;

                for (int k1 = 0; k1 < K; k1++) {
                    tacts.number += 1;
                    requests += 2;
//                    s += pa[k1] * pb[x]
                    cache.memAccess(createAddress(pa + k1), 1, tacts, hits, false);
                    cache.memAccess(createAddress(pb + 2 * x), 2, tacts, hits, false);
                    tacts.number += 5; //умножение
                    pb += 2 * N;
                    tacts.number += 1;
                }
//                pc[x] = s;
                requests += 1;
                cache.memAccess(createAddress(pc + 4 * x), 4, tacts, hits, true);
            }
            pa += K;
            tacts.number += 1;
            pc += 4 * N;
            tacts.number += 1;
        }
        tacts.number += 1;
        System.out.println("tacts: " + tacts.number + " pr hits: " + ((double) hits.number / (double) requests) * 100 + "%" + " hits: " + hits.number + "  requests " + requests);
    }
}
